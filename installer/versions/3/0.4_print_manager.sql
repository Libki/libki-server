ALTER TABLE print_jobs ADD COLUMN `released_on` timestamp NULL DEFAULT NULL;
ALTER TABLE print_jobs ADD COLUMN `queued_on` datetime NULL DEFAULT NULL;
ALTER TABLE print_jobs ADD COLUMN `queued_to` varchar(191) NULL DEFAULT NULL;
