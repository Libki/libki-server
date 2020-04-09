# Restore the fk from reservations to clients
ALTER TABLE reservations ADD CONSTRAINT reservations_ibfk_1 FOREIGN KEY (client_id) REFERENCES clients (id) ON DELETE CASCADE ON UPDATE CASCADE;
