DROP TABLE IF EXISTS webdata;
CREATE TABLE webdata (           
  message varchar(255) NOT NULL         
) ENGINE=MyISAM DEFAULT CHARSET=utf8;         

INSERT INTO webdata (message) VALUES ('Hello from MySQL');