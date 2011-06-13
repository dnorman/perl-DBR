Setting up your DBR application
===
This guide is intended to get you quickly set up the environment for your first DBR application.


*FIRST* Before reading this
---

See [README.md] and try out the examples

Setup Steps:
---

 1. Create your DBR database
   * SQLite:
     > sqlite3 /path/to/my/dbr.sqlite < sql/dbr_schema_sqlite.sql

   * Mysql:
      `create database dbr;` ( database name and access control are totally up to you )
      mysql -h mydbhost -u myuser -p'mypasswd' dbr < sql/dbr_schema_mysql.sql
 2. Create your DBR.conf
    Location is up to you.
    For SQLite:[
    `echo name=dbrconf; class=master; dbfile=/path/to/my/dbr.sqlite; type=SQLite; dbr_bootstrap=1 > /path/to/my/DBR.conf`
    For Mysql:
    `echo hostname=mydbhost; database=dbr; user=myuser; password=mypasswd; type=Mysql
dbr_bootstrap=1 > /path/to/my/DBR.conf`

 2. Define your schemas
 3. Define your instances
 4. Scan an instance
 5. Load Specifications
 