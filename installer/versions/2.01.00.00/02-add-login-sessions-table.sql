CREATE TABLE login_sessions (
    id           CHAR(72) PRIMARY KEY,
    session_data TEXT,
    expires      INTEGER
);
