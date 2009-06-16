

-- this is the application database schema
--                           +-----+
--                           | car |
--                           ++-+-++
--                            | | |
--                 +----------+ | +-------------------+
--                 |            |                     | 
--             +---+---+        |             +-------+-----+
--             | model |        |             | salesperson |
--             +---+---+   +----+--------+    +-------------+
--                 |       | car_feature |
--                 |       +----+--------+
--             +---+--+         |         
--             | make |         |         
--             +---+--+      +--+------+  
--                 |         | feature | 
--                 |         +---------+
--            +----+----+
--            | country |
--            +---------+


-- see DBR::Config::Relation.pm

insert into dbr_relationships values (NULL, 'cars',         1,2,  'model',       6,23, 2);
insert into dbr_relationships values (NULL, 'models',       6,24, 'make',        5,19, 2);
insert into dbr_relationships values (NULL, 'makes',        5,22, 'country',     3,13, 2);
insert into dbr_relationships values (NULL, 'car_features', 2,10, 'car',         1,1,  2);
insert into dbr_relationships values (NULL, 'car_features', 2,11, 'feature',     4,16, 2);
insert into dbr_relationships values (NULL, 'cars',         1,6,  'salesperson', 7,27, 2);
