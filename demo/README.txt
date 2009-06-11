
This is a demonstration directory.
The SQLite storage engine is used.

Everything needed to get things done is located right here.


What to do:


1) Read the introduction in the docs/ directory.

   It will be very helpful to understand the basic concepts
   at work when using perl-dbr.


2) Prerequisites

   You'll need the following:
   - zsh
   - Perl:
     - Clone
     - DBI
     - DBD::SQLite

   Installed DBR by running the deploy script.


3) Create the application database schema.

   The schema is for a car dealership.  Salespeople sell
   make/model cars with features.

   zsh> sqlite3 db/car_dealer.db < sql/create_car_dealer_database.sql


4) Create the metadata database.

   The smarts of perl-dbr come from metadata about tables,
   fields, and table relationships.  This metadata lives
   in its own database.

   zsh> sqlite3 db/metadata.db < sql/create_metadata_database.sql


5) Register the application database.

   We need to give the metadata database just enough information
   about the car_dealer database so that we can have perl-dbr
   then glean most of the metadata.

   zsh> sqlite3 db/metadata.db < sql/register_car_dealer.sql


6) Load the application database metadata.

   Perl-dbr comes with a schema scanner utility.  It needs the
   config file and the target database name (as registered above).

   zsh> ../bin/load_meta.pl conf/dbr.conf car_dealer

   Note that the name of the config may be specified as a third
   parameter to load_meta.pl, but defaults to "dbrconf".


7) Load the enumeration definitions.

   The available enumeration values are external information that
   you will need to register in the metadata database.

   zsh> sqlite3 db/metadata.db < sql/car_dealer_enumerations.sql

   Note that an admin tool will soon make this easier to do.

   Support is built in to perl-dbr to handle legacy enumerations.
   This is not within the scope of this demo.


8) Define additional metadata.

   We need to define the translator for enum, money and date fields.

   zsh> sqlite3 db/metadata.db < sql/car_dealer_translators.sql


   The admin tool will perform this function.


9) Define table relationships.

   Identify each foreign key relation in the database.
   Specify the name to use when referencing the relation from both the
   perspective of the table with the foreign key and the targeted table.

   zsh> sqlite3 db/metadata.db < sql/car_dealer_relationships.sql

   The admin tool will make this much easier.
   See doc/fkeys.txt file to match up the ids used in the SQL input file.


10) Test application actions.

   zsh> init.sh              (performs all the above actions)
   zsh> script/create.pl
   zsh> script/sampler.pl    (explore the DBR api with executed code samples)
   zsh> script/all_cars.pl
   zsh> script/add_car.pl


11) Something seem screwed up?

   just run the init.sh script and the script/create.pl script
   to reset all the demo data.

   and remember that all the demo scripts in ./script/ should be
   run from the demo directory!

   known bugs (2009-06-10):
   - count() won't work in SQLite unless you walk the resultset.
   - a null, undef or blank date will either fail or be incorrect.
     (this means you must enter a date_sold value in add_car.pl!).

   consider filing a bug report!

