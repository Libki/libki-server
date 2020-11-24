--
-- Table structure for table `allotments`
--

CREATE TABLE `allotments` (
  `instance` varchar(32) NOT NULL DEFAULT '',
  `user_id` int(11) NOT NULL,
  `location` varchar(191),
  `minutes` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`user_id`, `location`)
) ENGINE=InnoDB;

-- Constraints for table 'allotments'
--

ALTER TABLE `allotments`
    ADD CONSTRAINT `allotments_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Drop superfluous column from 'users'
--

ALTER TABLE `users`
    DROP COLUMN `minutes_allotment`;
