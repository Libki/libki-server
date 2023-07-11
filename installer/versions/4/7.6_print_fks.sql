ALTER TABLE print_files DROP FOREIGN KEY print_files_ibfk_1;
ALTER TABLE print_files ADD CONSTRAINT `print_files_ibfk_1` FOREIGN KEY (`client_id`) REFERENCES `clients` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE print_jobs DROP FOREIGN KEY print_jobs_ibfk_2;
ALTER TABLE print_jobs ADD CONSTRAINT `print_jobs_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;
