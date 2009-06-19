#!/bin/bash

# this performs all the actions in README.txt

rm -f db/*.db
sqlite3 db/car_dealer.db < sql/create_car_dealer_database.sql
sqlite3 db/metadata.db < sql/create_metadata_database.sql
sqlite3 db/metadata.db < sql/register_car_dealer.sql
perl -I../../lib ../../bin/load_meta.pl conf/dbr.conf car_dealer
sqlite3 db/metadata.db < sql/car_dealer_enumerations.sql
sqlite3 db/metadata.db < sql/car_dealer_translators.sql
# sqlite3 db/metadata.db < sql/car_dealer_relationships.sql
perl -I../../lib ../../bin/load_spec.pl conf=conf/dbr.conf spec=conf/meta.conf
