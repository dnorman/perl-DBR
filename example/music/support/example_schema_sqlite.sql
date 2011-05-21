
CREATE TABLE artist (
  artist_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  name varchar(250),
  genre int,
  status int,
  royalty_rate double
);

CREATE TABLE album (
  album_id INTEGER PRIMARY KEY DEFAULT NULL,
  artist_id int NOT NULL,
  name varchar(250) NOT NULL,
  rating smallint unsigned,
  date_released int unsigned
);

CREATE TABLE track (
  track_id INTEGER PRIMARY KEY DEFAULT NULL,
  album_id int NOT NULL,
  name varchar(250) NOT NULL
);
