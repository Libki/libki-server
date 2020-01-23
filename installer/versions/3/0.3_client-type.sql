ALTER TABLE clients ADD COLUMN `type` varchar(191) DEFAULT NULL AFTER `location`;
ALTER TABLE print_files ADD COLUMN `client_type` varchar(191) DEFAULT NULL AFTER `client_location`;
ALTER TABLE statistics ADD COLUMN `client_type` varchar(191) DEFAULT NULL AFTER `client_location`;
