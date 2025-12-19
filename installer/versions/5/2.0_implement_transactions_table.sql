CREATE TABLE transactions (
    id int(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,

    instance VARCHAR(32) COLLATE utf8_unicode_ci NOT NULL DEFAULT '',
    user_id int(11) NOT NULL,

    provider VARCHAR(32) NOT NULL,                 -- stripe, paypal, cash, etc
    provider_payment_id VARCHAR(128) NULL,         -- NULL for cash/manual

    amount_cents INT NOT NULL,
    currency CHAR(3) NOT NULL DEFAULT 'USD',

    status VARCHAR(32) NOT NULL,                   -- created, pending, succeeded, failed, refunded
    notes longtext COLLATE utf8_unicode_ci DEFAULT NULL,

    created_on DATETIME NOT NULL DEFAULT current_timestamp(),
    updated_on DATETIME NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),

    -- Prevent duplicates for gateway-based payments
    UNIQUE KEY uniq_provider_payment (
        instance,
        provider,
        provider_payment_id
    ),
    CONSTRAINT `user_transactions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,

    INDEX idx_instance_user (instance, user_id),
    INDEX idx_instance_status (instance, status),
    INDEX idx_created_on (created_on)
);

-- migrate users.funds to a transactions line
INSERT INTO transactions (
    instance,
    user_id,
    provider,
    provider_payment_id,
    amount_cents,
    currency,
    status,
    notes,
    created_on,
    updated_on
)
SELECT
    u.instance,
    u.id AS user_id,
    'cash' AS provider,
    NULL AS provider_payment_id,
    ROUND(u.funds * 100) AS amount_cents,
    'USD' AS currency,
    'migrated' AS status,
    'Initial balance migrated from user record' AS notes,
    NOW() AS created_on,
    NOW() AS updated_on
FROM users u
WHERE u.funds IS NOT NULL
  AND u.funds <> 0;


-- drop users.funds column
ALTER TABLE users DROP COLUMN funds;
