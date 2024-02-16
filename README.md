Findlinks
===========
Findlinks is a script for dumping a list of Wikipedia page names that contain one or more URLs for a given domain.

It answers the question: which pages on Enwiki have a cnn.com URL?

It can operate on 1 wiki, 2+ wikis, or all 300+ wikis.

It's useful for bot operators who need to know which articles to process for a given domain.

It's useful to dump all URLs for a given domain for whatever purpose.

It's useful to build other queries to answer other questions from the replication database.

Running
==========

See 0README for more detailed instructions.

How it works
=========
The script uses ssh to establish a tunnel with the replication server on Toolforge and then runs queries through the tunnel

Dependencies
====
* GNU awk 4.1+
* tcsh
* BotWikiAwk library
* mysql client

Setup 
=====
* Install MySQL client eg.

        sudo apt-get install mysql-client

* Install tcsh eg.

        sudo apt-get install tcsh

* Install BotWikiAwk library

        cd ~ 
        git clone 'https://github.com/greencardamom/BotWikiAwk'
        export AWKPATH=.:/home/user/BotWikiAwk/lib:/usr/share/awk
        export PATH=$PATH:/home/user/BotWikiAwk/bin
        cd ~/BotWikiAwk
        ./setup.sh
        (read SETUP for further instructions eg. setting up email)

* All program files are assumed to have some hard coded paths. Edit each and check for changes specific to your system.

* You will need a Toolforge account (free registration). Copy your replica.my.cnf file to the Findlinks local directory (it contains your SQL login ID and password)

Credits
==================
by User:GreenC (en.wikipedia.org)

MIT License Copyright 2024

Iabotwatch uses the BotWikiAwk framework of tools and libraries for building and running bots on Wikipedia

https://github.com/greencardamom/BotWikiAwk
