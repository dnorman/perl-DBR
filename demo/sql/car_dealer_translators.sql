
-- see README.txt

-- makes id assumptions!


-- set translators - see DBR::Config::Trans.pm

-- enum (car.color, model.style)
update dbr_fields set trans_id = 1 where field_id in (8,26);

-- dollars (car.price, car_feature.cost)
update dbr_fields set trans_id = 2 where field_id in (3,12);

-- unixtime (car.date_received, car.date_sold)
update dbr_fields set trans_id = 3 where field_id in (4,5);
