-- Reference schema and least-privilege application user.
-- The API also runs "CREATE TABLE IF NOT EXISTS" at start-up, so this file is only
-- needed to create the application user. scripts/init-db.sh renders it with the
-- password stored in AWS Secrets Manager (never commit real passwords).

CREATE DATABASE IF NOT EXISTS transactions;
USE transactions;

CREATE TABLE IF NOT EXISTS transactions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    amount INT,
    description VARCHAR(255)
);

CREATE USER IF NOT EXISTS 'expense'@'%' IDENTIFIED BY '__APP_PASSWORD__';
ALTER USER 'expense'@'%' IDENTIFIED BY '__APP_PASSWORD__';
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE ON transactions.* TO 'expense'@'%';
FLUSH PRIVILEGES;
