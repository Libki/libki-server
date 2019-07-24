   SET FOREIGN_KEY_CHECKS=0;
   ALTER TABLE `reservations`
     ADD `begin_time` datetime,
     ADD `end_time` datetime,
     DROP `expiration`,
     DROP INDEX `client_id`;
   INSERT INTO settings SET name='MinimumReservationMinutes', value='5';
   SET FOREIGN_KEY_CHECKS=1; 
