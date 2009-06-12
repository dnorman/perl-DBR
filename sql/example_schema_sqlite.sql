
CREATE TABLE artist (
  artist_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  name varchar(250),
  genre int,
  status int
);

CREATE TABLE album (
  album_id INTEGER PRIMARY KEY DEFAULT NULL,
  artist_id int NOT NULL,
  name varchar(250) NOT NULL
);

CREATE TABLE track (
  track_id INTEGER PRIMARY KEY DEFAULT NULL,
  album_id int NOT NULL,
  name varchar(250) NOT NULL
);


INSERT INTO "artist" VALUES(NULL,'Marilyn Manson',NULL,NULL);


INSERT INTO "album" VALUES(NULL,1,'Smells Like Children');
INSERT INTO "album" VALUES(NULL,1,'Portrait of an American Family');
INSERT INTO "album" VALUES(NULL,1,'Antichrist Superstar');
INSERT INTO "album" VALUES(NULL,1,'Mechanical Animals');
INSERT INTO "album" VALUES(NULL,1,'Holy Wood (In the Shadow of the Valley of Death)');
INSERT INTO "album" VALUES(NULL,1,'The Golden Age of Grotesque');
INSERT INTO "album" VALUES(NULL,1,'Eat Me, Drink Me');
INSERT INTO "album" VALUES(NULL,1,'The High End of Low');

