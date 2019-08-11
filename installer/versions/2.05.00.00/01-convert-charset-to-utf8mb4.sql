-- Convert everything to utf8mb4

ALTER DATABASE libki CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE client_age_limits CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE clients CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE closing_hours CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE jobs CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE locations CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE login_sessions CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE messages CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE print_files CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE print_jobs CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE reservations CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE roles CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE sessions CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE settings CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE statistics CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE user_roles CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
ALTER TABLE users CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

