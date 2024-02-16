#!/usr/bin/awk -bE

#
#
# Find external links across some or all wikis for a given domain
#
#

# The MIT License (MIT)
#
# Copyright (c) 2020 by User:GreenC (at en.wikipedia.org)
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

BEGIN { # Bot cfg

  _defaults = "home      = /home/greenc/toolforge/findlinks/ \
               email     = dfgf56greencard93@nym.hush.com \
               version   = 1.0 \
               copyright = 2024"

  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
  BotName = "findlinks"
  Home = G["home"]
  Agent = "Ask me about " BotName " - " G["email"]
  Engine = 3

  IGNORECASE = 1

}

@include "botwiki.awk"
@include "library.awk"

BEGIN {

  # Domain to search. No paths (results will show full URL). In reverse order eg. com.google.www
  Domain = "com.newindianexpress"

  # File to save output to
  Outfile = Home "newindianexpress.com"

  # Sites to search. Hard-code individual eg. "enwiki_p" or set to "ALL" - use codes from allwikis.txt
  # If "ALL" then see 0README how to generate list of allwikis.txt before running findlinks.awk
  Sites = "enwiki_p"

  # SQL type
  # "ARTICLES" will print the URL and article name. Currently the only option available.
  SQLType = "ARTICLES"

  if(checkexists(Outfile)) {
    print "Aborting due to existence of Outfile (" Outfile  ")" > "/dev/stderr"
    exit
  }

  if(!checkexists(Home "allwikis.txt")) {
    print "Aborting due missing allwikis.txt - run allwikis.sh first (see 0README)" > "/dev/stderr"
    exit
  }

  for(i = 1; i <= splitn(Home "allwikis.txt", a, i); i++) {

    if(Sites != "ALL" && Sites != a[i]) continue

    # This should come before the mysql command because if that fails and aborts, you will know where.
    # It should be stderr because a mysql abort will also be stderr
    stdErr("Processing " a[i])

    # Generate .sql file
    print_sql(a[i])

    if(checkexists(Home "cache")) 
      removefile2(Home "cache")

    # Create tunnel
    system("ssh -N -f -M -S " Home "findlinks-sock -L 4711:" gsubi("_p", "", a[i]) ".analytics.db.svc.wikimedia.cloud:3306 login.toolforge.org")

    # Run SQL query
    command = "mysql --defaults-file=" Home "replica.my.cnf --host=127.0.0.1 --port=4711 < " Home "findlinks.sql >> " Home "cache"
    system(command)
    close(Home "cache")

    # Kill tunnel
    system("ssh -S " Home "findlinks-sock -O exit login.toolforge.org")

    c = sys2var(Exe["awk"] " 'END{print NR}' " Home "cache") - 1 # subtract one for "el_to" line

    print c " " a[i]

    if(int(c) > 0) {
      sys2var(Exe["cat"] " " Home "cache | " Exe["grep"] " -v \"el_to\" >> " Outfile ".t")
      close(Outfile ".t")
      for(j = 1; j <= splitn(Outfile ".t", jj, j); j++) 
        print gsubi("_p", "", a[i]) "\t" jj[j] >> Outfile 
      close(Outfile)
      close(Outfile ".t")
    }
    removefile2(Home "cache")
    removefile2(Outfile ".t")
  } 

}

function print_sql(site,  f) {

  f = Home "findlinks.sql"

  if(SQLType == "RAWLINKS-OBSOLETE")  {  # Broken. Not sure how to do this with new style. https://phabricator.wikimedia.org/T312666
    print "USE " site ";" > f
    print "SELECT el_to, count(el_from) as pages" >> f
    print "FROM externallinks" >> f
    print "WHERE el_index LIKE \"%//" Domain ".%\"" >> f
    print "GROUP BY el_to" >> f
    print "ORDER BY pages DESC" >> f
  }

  else if(SQLType == "ARTICLES-OBSOLETE") { # https://phabricator.wikimedia.org/T312666
    print "USE " site ";" > f
    print "SELECT el_to, page_namespace, page_title" >> f
    print "FROM" >> f
    print "\texternallinks" >> f
    print "    JOIN page ON el_from = page_id" >> f
    print "WHERE el_index LIKE \"%//" Domain ".%\"" >> f
  }
  else if(SQLType == "ARTICLES-OLDVERSION1") { # per https://quarry.wmcloud.org/query/77247
    print "USE " site ";" > f
    print "SELECT page_title," >> f
    print "       page_namespace," >> f
    print "       el_to_domain_index," >> f
    print "       el_to_path" >> f
    print "FROM externallinks" >> f
    print "JOIN page ON page_id = el_from" >> f
    print "WHERE el_to_domain_index LIKE 'http://" Domain ".%' OR el_to_domain_index LIKE 'https://" Domain ".%'" >> f
  }
  else if(SQLType == "ARTICLES") { # per https://quarry.wmcloud.org/query/77235
    print "USE " site ";" > f
    print "SELECT page_title," >> f
    print "       page_namespace," >> f
    print "       CONCAT(REGEXP_REPLACE(el_to_domain_index, '^(.*?://)(?:([^.]+)\\\\.)([^.]+\\\\.)?([^.]+\\\\.)?([^.]+\\\\.)?([^.]+\\\\.)?([^.]+\\\\.)?([^.]+\\\\.)?([^.]+\\\\.)$','\\\\1\\\\9\\\\8\\\\7\\\\6\\\\5\\\\4\\\\3\\\\2'),el_to_path) AS url" >> f
    print "FROM externallinks" >> f
    print "JOIN page ON page_id = el_from" >> f
    print "WHERE el_to_domain_index LIKE 'http://" Domain ".%' OR el_to_domain_index LIKE 'https://" Domain ".%'" >> f
  }
  else {
    print "No viable method."
    exit
  }

  close(f)

}

