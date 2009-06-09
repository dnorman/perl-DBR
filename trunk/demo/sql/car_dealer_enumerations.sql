
-- see README.txt

-- makes id assumptions!


-- style (1-7)
insert into enum values (NULL,'coupe',    'Coupe',    NULL);
insert into enum values (NULL,'hatchback','Hatchback',NULL);
insert into enum values (NULL,'sedan',    'Sedan',    NULL);
insert into enum values (NULL,'suv',      'SUV',      NULL);
insert into enum values (NULL,'pickup',   'Pickup',   NULL);
insert into enum values (NULL,'wagon',    'Wagon',    NULL);
insert into enum values (NULL,'compact',  'Compact',  NULL);

-- map to model.style (field_id = 26)
insert into enum_map values (NULL,26,1,1);
insert into enum_map values (NULL,26,2,2);
insert into enum_map values (NULL,26,3,3);
insert into enum_map values (NULL,26,4,4);
insert into enum_map values (NULL,26,5,5);
insert into enum_map values (NULL,26,6,6);
insert into enum_map values (NULL,26,7,7);


-- color (8-15)
insert into enum values (NULL,'red','Red',NULL);
insert into enum values (NULL,'blue','Blue',NULL);
insert into enum values (NULL,'green','Green',NULL);
insert into enum values (NULL,'yellow','Yellow',NULL);
insert into enum values (NULL,'white','White',NULL);
insert into enum values (NULL,'black','Black',NULL);
insert into enum values (NULL,'silver','Silver',NULL);
insert into enum values (NULL,'maroon','Maroon',NULL);

-- map to car.color (field_id=8)
insert into enum_map values (NULL,8,8,1);
insert into enum_map values (NULL,8,9,2);
insert into enum_map values (NULL,8,10,3);
insert into enum_map values (NULL,8,11,4);
insert into enum_map values (NULL,8,12,5);
insert into enum_map values (NULL,8,13,6);
insert into enum_map values (NULL,8,14,7);
insert into enum_map values (NULL,8,15,8);
