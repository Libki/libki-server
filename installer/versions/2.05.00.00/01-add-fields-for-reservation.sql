   ALTER TABLE reservations DROP FOREIGN KEY reservations_ibfk_1;
   ALTER TABLE `reservations`
     ADD `begin_time` datetime,
     ADD `end_time` datetime,
     DROP `expiration`,
     DROP INDEX `client_id`;
   INSERT INTO settings SET name='MinimumReservationMinutes', value='5';
