Findlinks
===========
Findlinks is a script for dumping a list of Wikipedia page names where the article contains any URLs for a given domain.

It answers the question: which pages on Enwiki include a cnn.com URL?

It can operate on 1 wiki, 2+ wikis, or all 800+ wikis.

It's useful for bot operators who need to know which articles to process for a given domain.

It can dump all URLs for a given domain, or for all domains, for some sites, or all sites.

It's useful to build other queries to answer other questions from the replication database.

Running
==========

	  findlinks - list page names that contain a domain
	
	    -d <domain>   (required) Domain to search for eg. cnn.com
	                    if "ALL" then retrieve every URL for every domain. -k will be enabled by default
	    -s <site>     (required) One or more site codes [space seperated] - see allwikis.txt for the list
	                    If "ALL" then process all sites (800+) in allwikis.txt
	                    If "<whatever>.txt" then process all site codes listed in the file <whatever>.txt
	                    Use of the trailing "_p" in the site code is supported but optional - see Examples below
	    -n <ns>       (optional) Namespace(s) to target [space seperated]. Default is "0 6"
	                    eg. -n "0 6 10" will check these 3 namespaces 
	                    0 = mainspace, 6 = File: and 10 = Template:
	    -r <regex>    (optional) Only report URLs that match the given regex
	    -k            (optional) Keep raw output file. Useful for viewing the URLs
	    -a            (optional) Generate a fresh copy of allwikis.txt - ie. a list of all wiki site codes

	    Examples:
	      Find all pages on enwiki in namespace 4 & 5 that contain 'archive.md'
	         ./findlinks -d archive.md -s enwiki -n '4 5'
	      Find all pages on enwiki and eswiki in namespace 0 that contain archive.md
	         ./findlinks -d archive.md -s 'enwiki eswiki' -n 0
	      Find all pages on the sites listed in mylist.txt in namespace 0 & 6 that contain archive.md
	         ./findlinks -d archive.md -s mylist.txt
	      Find all pages on enwiki in namespace 0 & 6 that contain a URL with '^http:' and 'archive.today'
	         ./findlinks -d archive.today -s enwiki -r '^http:'
	      Dump all links in all wikis for namespaces 0 and 6
	         ./findlinks -d ALL -s ALL -n "0 6"
	      Dump all links in the sites listed in domains.txt
	         ./findlinks -d ALL -s domains.txt
	      Dump all cnn.com links in all sites in namespace 1
	         ./findlinks -d cnn.com -s ALL -n 1

How it works
=========
The script uses ssh to establish a tunnel with the replication server on Toolforge and then runs queries through the tunnel. It can run from any computer it doesn't need to be hosted on Toolforge.

Dependencies
====
* GNU awk 4.1+
* MySql client
* ssh client
* A Wikitech Toolforge account: https://wikitech.wikimedia.org/wiki/Portal:Toolforge

Setup 
=====
* Clone the repo

        cd ~
        git clone 'https://github.com/greencardamom/Findlinks'

* Install a MySQL client if not already:

        sudo apt-get install mysql-client

* findlinks.awk has a hard coded path at the top of the file for the "Home" directory.

* You will need a Toolforge account (free registration). Copy your replica.my.cnf file to the Findlinks local directory (it contains your SQL login ID and password)

* You will need passwordless ssh access. Run 'ssh-keygen' and copy-paste the content of ~/.ssh/id_rsa.pub to your toolforge account at https://admin.toolforge.org/ under "Add a ssh public key"

Credits
==================
by User:GreenC (en.wikipedia.org)

MIT License Copyright 2024

Iabotwatch uses the BotWikiAwk framework of tools and libraries for building and running bots on Wikipedia

https://github.com/greencardamom/BotWikiAwk
