#!/usr/bin/awk -bE

#
# Find external links across some or all wikis for a given domain
#
# Alternative method using Quarry: https://quarry.wmcloud.org/query/80435
#

# The MIT License (MIT)
#
# Copyright (c) 2020-2024 by User:GreenC (at en.wikipedia.org)
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

BEGIN {

  Home = "/home/greenc/toolforge/findlinks/"

  Namespace = "0 6"  # default

  IGNORECASE = 1

  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "akd:s:n:")) != -1) {
      opts++
      if(C == "d")                 #  -d <domain>     Domainame eg. "cnn.com"
        Domain = verifyval(Optarg)
      if(C == "s")                 #  -s <site>       Site(s) eg. "enwiki_p"
        Sites = verifyval(Optarg)
      if(C == "n")                 #  -i <namespace>  Namespace eg. "0" or "0 6 10" - default "0 6"
        Namespace = verifyval(Optarg)
      if(C == "k")                 #  -k              Keep raw outfile
        Keepfile = 1
      if(C == "a")                 #  -a              Generate a fresh allwikis.txt file
        Allwikistxt = 1
  }
 
  if(Allwikistxt) {
    create_allwikistxt()
    print "Created " Home "allwikis.txt"
    exit
  }

  if(opts == 0 || empty(Domain) || empty(Sites) ) {
    help()
    exit(0)
  }

  main()
  
}

function main(  i,c,b,a,oDomain,tunnelsock,command,j,jj,re,RES,ns,wp,k,site,e,g,sitefilename,h) {

  oDomain = Domain

  # Reverse domain eg. com.cnn.www
  c = split(reverse(Domain), a, "[.]")
  Domain = reverse(a[1])
  for(i = 2; i <= c; i++) 
    Domain = Domain "." reverse(a[i])
  
  # File to save output to
  Outfile = Home oDomain

  # SQL type
  # "ARTICLES" will print the URL and article name. Currently the only option available.
  SQLType = "ARTICLES"

  if(!checkexists(Home "replica.my.cnf")) {
    print "Aborting missing " Home "replica.my.cnf" > "/dev/stderr"
    exit
  }

  # Set default site list file
  if(Sites ~ ".txt$") {
    sitefilename = Sites
    Sites = "ALL"
  }
  else
    sitefilename = "allwikis.txt"

  # Create a fresh copy of allwikis.txt if running "ALL"
  if(sitefilename == "allwikis.txt" && Sites == "ALL") {

    create_allwikistxt()

    if(!checkexists(Home "allwikis.txt")) {
      print "Aborting due missing allwikis.txt" > "/dev/stderr"
      exit
    }
  }

  if(Sites != "ALL")
    e = split(Sites, site, " ")
  else
    e = splitn(Home sitefilename, site)

  for(g = 1; g <= e; g++) {

    # Normalize format
    if(site[g] ~ "_p$")
      sub("_p$", "", site[g])

    if(checkexists(Home "cache")) 
      removefile2(Home "cache")

    Outfile = Outfile "." site[g]

    if(checkexists(Outfile) && Keepfile) {
      print "Aborting due to existence of Outfile (" Outfile  ") and -k option. Either delete the Outfile or don't use -k" > "/dev/stderr"
      exit
    }
    else if(checkexists(Outfile))
      removefile2(Outfile)

    # PID of ssh tunnel
    tunnelsock = mktemp(Home "tunnelsock.XXXXXX", "u")

    # Create tunnel 
    command = "ssh -N -f -M -S " tunnelsock " -L 4711:" site[g] ".analytics.db.svc.wikimedia.cloud:3306 login.toolforge.org"
    system(command)

    # Generate .sql file
    print_sql(site[g] "_p")

    # Run SQL query
    command = "mysql --defaults-file=" Home "replica.my.cnf --host=127.0.0.1 --port=4711 < " Home "findlinks.sql >> " Home "cache"
    system(command)
    close(Home "cache")

    # Kill tunnel
    sys2var("ssh -S " tunnelsock " -O exit login.toolforge.org", 1)

    c = sys2var("awk 'END{print NR}' " Home "cache") - 1 # subtract one for "el_to" line

    if(int(c) > 0) {
      sys2var("cat " Home "cache | grep -v \"el_to\" > " Outfile ".t")
      close(Outfile ".t")
      delete jj
      for(j = 1; j <= splitn(Outfile ".t", jj, j); j++) 
        print site[g] "\t" jj[j] >> Outfile 
      close(Outfile)
      close(Outfile ".t")
    }
    removefile2(Home "cache")
    removefile2(Outfile ".t")

    # Print page names from raw Outfile
    # awk -v re='^(0|6)$' -ilibrary '{c=split($0,a," "); if(c==4) {ns=strip($3);wp=gsubi("_"," ",strip($2)); if(ns~re) {if(wp ~ /[.](jpeg|jpg|png|svg|gif|pdf)$/) {wp = "File:" wp}; print wp } }}' newindianexpress.com | auniq > newindianexpress.auth

    re = "^(" gsubi(" ", "|", Namespace) ")$"
    delete RES
    delete a
    for(i = 1; i <= splitn(Outfile, a, i); i++) {
      c = split(a[i], b, " ")
      if(c == 4) {
        ns = strip(b[3])
        wp = gsubi("_"," ",strip(b[2]))
        if(ns ~ re) {
          if(wp ~ /[.](jpeg|jpg|png|svg|gif|pdf)$/) 
            wp = "File:" wp          
          RES[wp] = 1
        }
      }
    }
    # Unique the list
    for(k in RES) {
      if(e > 1 || Sites == "ALL" )
        print site[g] "\t" k
      else
        print k
    }
  } 
  if(Keepfile != 1)
    removefile2(Outfile)
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

#
# Create allwikis.sql
#
function print_allwikissql(  f) {
  f = Home "allwikis.sql"
  print "use meta_p;" > f
  print "SELECT * FROM wiki;" >> f
  close(f)
}

#
# Create allwikis.txt
#
function create_allwikistxt(  tunnelsock,command) {

    # PID of ssh tunnel
    tunnelsock = mktemp(Home "tunnelsock.XXXXXX", "u")

    # Create tunnel to meta
    command = "ssh -N -f -M -S " tunnelsock " -L 4711:meta.analytics.db.svc.wikimedia.cloud:3306 login.toolforge.org"
    system(command)

    # Generate .sql file
    print_allwikissql()

    # Run command
    command = "mysql --defaults-file=" Home "replica.my.cnf --host=127.0.0.1 --port=4711 < " Home "allwikis.sql | grep -v Database | awk '{split($0,a,/\\t/); if(a[8] == 0) print a[1] \"_p\"}' > " Home "allwikis.txt"
    system(command)
    close(Home "allwikis.txt") 

    # Kill tunnel to meta
    command = "ssh -S " tunnelsock " -O exit login.toolforge.org"
    sys2var(command, 1)

}

function help() {

  print "\n  findlinks - list page names that contain a domain\n"
  print "    -d <domain>   (required) Domain to search for eg. cnn.com"
  print "    -s <site>     (required) One or more site codes [space seperated] - see allwikis.txt for the list"
  print "                             If \"ALL\" then process all sites (800+) in allwikis.txt"
  print "                             If \"<whatever>.txt\" then process all site codes listed in the file <whatever>.txt"
  print "                             Use of the trailing "_p" in the site code is supported but optional - see Examples below"
  print "    -n <ns>       (optional) Namespace(s) to target [space seperated]. Default is \"" Namespace "\""
  print "                             eg. -n \"0 6 10\" will check these 3 namespaces "
  print "                             0 = mainspace, 6 = File: and 10 = Template:"
  print "    -k            (optional) Keep raw output file. Useful for viewing the URLs"
  print "    -a            (optional) Generate a fresh copy of allwikis.txt - ie. a list of all wiki site codes"
  print ""
  print "    Examples:"
  print "      Find all pages on enwiki in namespace 4 & 5 that contain archive.md"
  print "         ./findlinks -d archive.md -s enwiki -n '4 5'"
  print "      Find all pages on enwiki and eswiki in namespace 0 that contain archive.md"
  print "         ./findlinks -d archive.md -s 'enwiki eswiki' -n 0"
  print "      Find all pages on the sites listed in mylist.txt in namespace 0 & 6 that contain archive.md"
  print "         ./findlinks -d archive.md -s mylist.txt"
  print ""

}

# -----------------------
#
# Library functions from: https://github.com/greencardamom/BotWikiAwk/blob/master/lib/library.awk
#
# -----------------------

#
# empty() - return 0 if string is 0-length
#
function empty(s) {
    if (length(s) == 0)
        return 1
    return 0   
}

#
# exists2() - check for file existence
#
#   . return 1 if exists, 0 otherwise.
#   . no dependencies
#
function exists2(file    ,line, msg) {
    if ((getline line < file) == -1 ) {
        msg = (ERRNO ~ /Permission denied/ || ERRNO ~ /a directory/) ? 1 : 0
        close(file)   
        return msg
    }
    else {
        close(file)
        return 1
    }
}

#
# checkexists() - check file or directory exists. 
#
#   . action = "exit" or "check" (default: check)
#   . return 1 if exists, or exit if action = exit
#   . requirement: @load "filefuncs"
#
function checkexists(file, program, action) {                       
    if ( ! exists2(file) ) {              
        if ( action == "exit" ) {
            stdErr(program ": Unable to find/open " file)
            print program ": Unable to find/open " file  
            system("")
            exit
        }
        else
            return 0
    }
    else
        return 1
}


#
# splitn() - split input 'fp' along \n
#
#  Designed to replace typical code sequence
#      fp = readfile("test.txt")
#      c = split(fp, a, "\n")
#      for(i = 1; i <= c; i++) {
#        if(length(a[i]) > 0) 
#          print "a[" i "] = " a[i]
#      }
#  With
#      for(i = 1; i <= splitn("test.txt", a, i); i++) 
#        print "a[" i "] = " a[i]
#
#   . If input is the name of a file, it will readfile() it; otherwise use literal text as given 
#   . Automatically removes blank lines from input
#   . Allows for embedding in for-loops 
#
#   Notes
#
#   . The 'counter' ('i' in the example) is assumed initialized to 1 in the for-loop. If
#     different, pass a start value in the fourth argument eg.
#             for(i = 5; i <= splitn("test.txt", a, i, 5); i++)
#   . If not in a for-loop the counter is not needed eg.
#             c = splitn("test.txt", a)
#   . 'fp' can be a filename, or a string of literal text. If 'fp' does not contain a '\n'
#     it will search for a filename of that name; if none found it will treat as a
#     literal string. If it means to be a string, for safety add a '\n' to end. eg.
#             for(i = 5; i <= splitn(ReadDB(key) "\n", a, i); i++)
#       
function splitn(fp, arrSP, counter, start,    c,j,dSP,i,save_sorted) {

    if ( empty(start) ) 
        start = 1 
    if (counter > start) 
        return length(arrSP) 

    if ("sorted_in" in PROCINFO) 
        save_sorted = PROCINFO["sorted_in"]
    PROCINFO["sorted_in"] = "@ind_num_asc"

    if (fp !~ /\n/) {
        if (checkexists(fp))      # If the string doesn't contain a \n check if a filename exists
            fp = readfile(fp)     # with that name. If not assume it's a literal string. This is a bug
    }                             # in case a filename exists with the same name as the literal string.

    delete arrSP
    c = split(fp, dSP, "\n")
    for (j in dSP) {
        if (empty(dSP[j])) 
            delete dSP[j]
    }
    i = 1
    for (j in dSP)  {
        arrSP[i] = dSP[j]
        i++
    }

    if (save_sorted)
        PROCINFO["sorted_in"] = save_sorted
    else
        PROCINFO["sorted_in"] = ""

    return length(dSP)

}

# 
# stdErr() - print s to /dev/stderr
#
#  . if flag = "n" no newline
#
function stdErr(s, flag) {
    if (flag == "n")
        printf("%s",s) > "/dev/stderr"
    else
        printf("%s\n",s) > "/dev/stderr"
    close("/dev/stderr")
}


#   
# removefile2() - delete a file/directory
#
#   . no wildcards
#   . return 1 success
#
#   Requirement: rm
#
function removefile2(str) {

    if (str ~ /[*|?]/ || empty(str))  
        return 0
    system("") # Flush buffer
    if (exists2(str)) { 
      system("rm -r -- " shquote(str) )
      system("")
      if (! exists2(str))
        return 1
    }
    return 0
}

#
# readfile() - same as @include "readfile"        
#
#   . leaves an extra trailing \n just like with the @include readfile
#
#   Credit: https://www.gnu.org/software/gawk/manual/html_node/Readfile-Function.html by Denis Shirokov
#
function readfile(file,     tmp, save_rs) {
    save_rs = RS
    RS = "^$"
    getline tmp < file
    close(file)
    RS = save_rs
    return tmp
}

#
# sys2var() - run a system command and store result in a variable
#   
#  . supports pipes inside command string
#  . stderr is sent to null
#  . if command fails (errno) return null
#
#  Example:
#     googlepage = sys2var("wget -q -O- http://google.com")
#
function sys2var(command, quiet        ,fish, scale, ship) {

    if(quiet) 
      command = command " 2>/dev/null"
    while ( (command | getline fish) > 0 ) {
        if ( ++scale == 1 )  
            ship = fish 
        else
            ship = ship "\n" fish
    }
    close(command)
    system("")
    return ship
}

#
# gsubi() - same as gsub() but leave source string unmodified and return new string
#
#   Example:
#      s = "Plain"
#      print gsubi("^P", "p", s) " = " s   #=> plain = Plain
#
function gsubi(pat, rep, str,   safe) {

    if (!length(pat) || !length(str)) 
        return
    safe = str
    gsub(pat, rep, safe)
    return safe
            
}

#
# verifyval - verify any command-line argument has valid value. Usage in getopt()
#
function verifyval(val) {
  if(val == "" || substr(val,1,1) ~/^[-]/) {
    stdErr("Command line argument has an empty value when it should have something.")
    exit
  }
  return val
}

#
# getopt() - command-line parser
#
#   . define these globals before getopt() is called: 
#        Optind = Opterr = 1
#
#   Credit: GNU awk (/usr/local/share/awk/getopt.awk)
#
function getopt(argc, argv, options,    thisopt, i) {

    if (length(options) == 0)    # no options given
        return -1

    if (argv[Optind] == "--") {  # all done
        Optind++
        _opti = 0
        return -1
    } else if (argv[Optind] !~ /^-[^:[:space:]]/) {
        _opti = 0
        return -1
    }
    if (_opti == 0)
        _opti = 2  
    thisopt = substr(argv[Optind], _opti, 1)
    Optopt = thisopt
    i = index(options, thisopt)
    if (i == 0) {
        if (Opterr)
            printf("%c -- invalid option\n", thisopt) > "/dev/stderr"
        if (_opti >= length(argv[Optind])) {
            Optind++
            _opti = 0
        } else
            _opti++
        return "?"
    }
    if (substr(options, i + 1, 1) == ":") {
        # get option argument
        if (length(substr(argv[Optind], _opti + 1)) > 0)
            Optarg = substr(argv[Optind], _opti + 1)
        else
            Optarg = argv[++Optind]
        _opti = 0
    } else
        Optarg = ""
    if (_opti == 0 || _opti >= length(argv[Optind])) {
        Optind++
        _opti = 0
    } else
        _opti++
    return thisopt
}


#
# reverse() - reverse a string
#                  
function reverse(s,  a,i,n) {             

    c = split(s, a, "")
    for(i = c; i >= 1; i--)
        n = n a[i]
    return n

}         


#
# mktemp() - make a temporary unique file or directory and/or returns its name
#
#  . the last six characters of 'template' must be "XXXXXX" which will be replaced by a uniq string
#  . if template is not a pathname, the file will be created in ENVIRON["TMPDIR"] if set otherwise /tmp
#  . if template not provided defaults to "tmp.XXXXXX"
#  . recommend don't use spaces or " or ' in pathname
#  . if type == f create a file
#  . if type == d create a directory
#  . if type == u return the name but create nothing
#
#  Example:
#     outfile = mktemp(meta "index.XXXXXX", "u")
#
#  Credit: https://github.com/e36freak/awk-libs
#  mods by GreenC
#
function mktemp(template, type,                 
                c, chars, len, dir, dir_esc, rstring, i, out, out_esc, umask,
                cmd) {           
 
  # portable filename characters
    c = "012345689ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    len = split(c, chars, "")
    
  # make sure template is valid
    if (length(template)) {
        if (template !~ /XXXXXX$/) {
            return -1
        } 
        
  # template was not supplied, use the default
    } else {
        template = "tmp.XXXXXX"
    }         
  # make sure type is valid
    if (length(type)) {
        if (type !~ /^[fdu]$/) {
            return -1
        }
  # type was not supplied, use the default
    } else {
        type = "f"
    }

  # if template is a path...
    if (template ~ /\//) {
        dir = template
        sub(/\/[^/]*$/, "", dir)
        sub(/.*\//, "", template)
  # template is not a path, determine base dir
    } else {                                              
        if (length(ENVIRON["TMPDIR"])) {
            dir = ENVIRON["TMPDIR"]
        } else {
            dir = "/tmp"
        }
    }

  # if this is not a dry run, make sure the dir exists
    if (type != "u" && ! exists(dir)) {
        return -1
    }

  # get the base of the template, sans Xs
    template = substr(template, 0, length(template) - 6)

  # generate the filename
    do {
        rstring = ""
        for (i=0; i<6; i++) {
            c = chars[int(rand() * len) + 1]
            rstring = rstring c
        }
        out = dir "/" template rstring
    } while( exists2(out) )

    if (type == "f") {
        printf "" > out
        close(out)
    } else if (type == "d") {
        mkdir(out)
    }
    return out
}

# 
# shquote() - make string safe for shell
#
#  . an alternate is shell_quote.awk in /usr/local/share/awk which uses '"' instead of \'
#
#  Example:
#     print shquote("Hello' There")    produces 'Hello'\'' There'              
#     echo 'Hello'\'' There'           produces Hello' There                 
# 
function shquote(str,  safe) {
    safe = str
    gsub(/'/, "'\\''", safe)
    gsub(/’/, "'\\’'", safe)
    return "'" safe "'"
}


# 
# strip() - strip leading/trailing whitespace
#
#   . faster than the gsub() or gensub() methods eg.
#        gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
#        gensub(/^[[:space:]]+|[[:space:]]+$/,"","g",s)
#
#   Credit: https://github.com/dubiousjim/awkenough by Jim Pryor 2012
# 
function strip(str) {
    if (match(str, /[^ \t\n].*[^ \t\n]/))
        return substr(str, RSTART, RLENGTH)
    else if (match(str, /[^ \t\n]/))
        return substr(str, RSTART, 1)
    else
        return ""
}

