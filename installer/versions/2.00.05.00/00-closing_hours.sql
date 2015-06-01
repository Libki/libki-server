--
-- Table structure for table 'closing_hours'
--

CREATE TABLE IF NOT EXISTS closing_hours (
  day varchar(255) CHARACTER SET utf8 NOT NULL,
  closing_time varchar(255) CHARACTER SET utf8 NOT NULL,
  PRIMARY KEY (day)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

# Update the version
# UPDATE settings SET value = '2.00.05.000' WHERE name = "Version";
