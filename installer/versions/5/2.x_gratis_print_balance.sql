ALTER TABLE `users`
  ADD COLUMN `gratis_print_balance` INT(11) NOT NULL DEFAULT 0
  COMMENT 'Number of free prints remaining; represents pages or cents depending on system settings';
