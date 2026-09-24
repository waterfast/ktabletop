CREATE TABLE IF NOT EXISTS userInfo (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username VARCHAR(64) NOT NULL,
    displayName VARCHAR(64),
    password CHAR(64),
    salt CHAR(8),
    banned BOOLEAN
);

CREATE TABLE IF NOT EXISTS userAuditInfo (
    id INTEGER PRIMARY KEY,
    registeredAt INTEGER NOT NULL DEFAULT(unixepoch()),
    lastLoginAt INTEGER NOT NULL DEFAULT(unixepoch()),
    lastLoginIp VARCHAR(16)
);
