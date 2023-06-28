ALTER TABLE clients ADD COLUMN `ipaddress` varchar(191) DEFAULT NULL AFTER `type`;
ALTER TABLE clients ADD COLUMN `macaddress` varchar(191) DEFAULT NULL AFTER `ipaddress`;
ALTER TABLE clients ADD COLUMN `hostname` varchar(191) DEFAULT NULL AFTER `macaddress`;

