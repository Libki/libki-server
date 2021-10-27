UPDATE settings
SET value = IF(value = 0 OR value = 1, "RSD", "RSFN")
WHERE name = "ReservationShowUsername";
