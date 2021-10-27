UPDATE settings
SET value = IF(value = 0, "RSD", "RSFN")
WHERE name = "ReservationShowUsername";
