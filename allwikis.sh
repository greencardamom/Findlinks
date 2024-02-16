#!/usr/bin/tcsh

if(-e allwikis.txt) /bin/mv allwikis.txt allwikis.txt.bak

# No longer works September 2021
# /usr/bin/mysql --defaults-file=$HOME/replica.my.cnf -h enwiki.analytics.db.svc.eqiad.wmflabs enwiki_p < $HOME/findlinks/allwikis.sql.old | /bin/grep -v "Database" > $HOME/findlinks/allwikis.txt

# Toolforge version
# Filter out closed sites (field 8 != 0 in awk command)
# /usr/bin/mysql --defaults-file=$HOME/toolforge/replica.my.cnf -h meta.analytics.db.svc.wikimedia.cloud < $HOME/toolforge/findlinks/allwikis.sql | /bin/grep -v "Database" | awk '{split($0,a,"\t"); if(a[8] == 0) print a[1] "_p"}' > $HOME/toolforge/findlinks/allwikis.txt

# SSH Tunnel version see https://wikitech.wikimedia.org/wiki/Help:Toolforge/Database
# -----------------------

# Create tunnel 
ssh -N -f -M -S /tmp/file-sock -L 4711:meta.analytics.db.svc.wikimedia.cloud:3306 login.toolforge.org
sleep 2

# Run SQL query
/usr/bin/mysql --defaults-file=$HOME/toolforge/replica.my.cnf --host=127.0.0.1 --port=4711 < $HOME/toolforge/findlinks/allwikis.sql | /bin/grep -v "Database" | awk '{split($0,a,"\t"); if(a[8] == 0) print a[1] "_p"}' > $HOME/toolforge/findlinks/allwikis.txt
sleep 2

# Kill tunnel
ssh -S /tmp/file-sock -O exit login.toolforge.org
