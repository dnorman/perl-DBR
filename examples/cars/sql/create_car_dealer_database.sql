
-- see README.txt

-- this is the application database schema
--                          +------+
--                          | race |
--                          +--+-+-+
--                             | |
--                           +-+-+-+
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

-- monetary values are in cents.
-- date values are epoch time.

-- example: VW, Volkswagon, 2
create table make (
  make_id integer primary key autoincrement,
  name varchar(32) not null,
  longname varchar(64),
  country_id int
);

-- examples: 740i/sedan, Cabrio GLS/convertible, 350Z/coupe
create table model (
  model_id integer primary key autoincrement,
  make_id int not null,
  name varchar(32) not null,
  style tinyint
);

-- examples: sunroof, leather seats, power hatch
create table feature (
  feature_id integer primary key autoincrement,
  name varchar(64) not null,
  description varchar(250)
);

-- register features for a car on the lot
-- if added by dealer, the cost is registered
create table car_feature (
  car_feature_id integer primary key autoincrement,
  car_id int not null,
  feature_id int not null,
  cost int not null
);

-- a car that is available
create table car (
  car_id integer primary key autoincrement,
  model_id int not null,
  price int not null,
  date_received int not null,
  date_sold int,
  salesperson_id int,
  model_year smallint not null,
  color tinyint not null
);

create table salesperson (
  salesperson_id integer primary key autoincrement,
  name varchar(64) not null
);

create table country (
  country_id integer primary key autoincrement,
  name varchar(32) not null,
  abbrev varchar(8)
);

create table race (
  race_id integer primary key autoincrement,
  car_one int not null,
  car_two int not null,
  event varchar(64) not null
);
