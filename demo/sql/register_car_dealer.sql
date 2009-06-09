
-- see README.txt --

-- there will be an admin tool to do this soon --

insert into dbr_schemas (handle,display_name) values ('car_dealer','Example Car Dealership Database');
insert into dbr_instances (schema_id,handle,class,dbfile,module) values (1,'car_dealer','master','db/car_dealer.db','SQLite');
insert into dbr_instances (schema_id,handle,class,dbfile,module) values (1,'car_dealer','query', 'db/car_dealer.db','SQLite');
