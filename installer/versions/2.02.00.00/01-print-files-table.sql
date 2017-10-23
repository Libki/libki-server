CREATE TABLE IF NOT EXISTS print_files (
  id int(11) NOT NULL AUTO_INCREMENT,
  filename text NOT NULL,
  content_type varchar(255) NULL DEFAULT NULL,
  data blob NULL,
  client_id int(11) NULL DEFAULT NULL,
  client_name  varchar(255) NOT NULL,
  PRIMARY KEY(id),
  FOREIGN KEY(client_id) REFERENCES clients(id) ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
