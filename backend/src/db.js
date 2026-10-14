'use strict';

const mysql = require('mysql2/promise');
const config = require('./config');

let pool;

function getPool() {
  if (!pool) {
    pool = mysql.createPool({
      host: config.db.host,
      port: config.db.port,
      user: config.db.user,
      password: config.db.password,
      database: config.db.database,
      waitForConnections: true,
      connectionLimit: config.db.poolSize,
      queueLimit: 0,
      connectTimeout: 10000,
      enableKeepAlive: true,
    });
  }
  return pool;
}

/** Run a parameterised statement. Never build SQL with string concatenation. */
async function query(sql, params = []) {
  const [result] = await getPool().execute(sql, params);
  return result;
}

async function ping() {
  await getPool().query('SELECT 1');
}

async function ensureSchema() {
  await getPool().query(`
    CREATE TABLE IF NOT EXISTS transactions (
      id INT AUTO_INCREMENT PRIMARY KEY,
      amount INT,
      description VARCHAR(255)
    )`);
}

async function close() {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
}

module.exports = { query, ping, ensureSchema, close };
