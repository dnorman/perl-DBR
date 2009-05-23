
CREATE TABLE artist (
  artist_id int(10) PRIMARY KEY DEFAULT NULL,
  name varchar(250),
  genre int,
  status int
);

CREATE TABLE album (
  album_id int(10) PRIMARY KEY DEFAULT NULL,
  artist_id int NOT NULL,
  name varchar(250) NOT NULL
);

CREATE TABLE track (
  track_id int(10) PRIMARY KEY DEFAULT NULL,
  album_id int NOT NULL,
  name  int(10) NOT NULL
);
