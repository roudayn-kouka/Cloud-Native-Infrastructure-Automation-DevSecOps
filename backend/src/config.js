'use strict';

const toInt = (value, fallback) => {
  const parsed = Number.parseInt(value, 10);
  return Number.isNaN(parsed) ? fallback : parsed;
};

module.exports = {
  env: process.env.NODE_ENV || 'development',
  port: toInt(process.env.PORT, 8080),
  logLevel: process.env.LOG_LEVEL || 'info',
  corsOrigin: process.env.CORS_ORIGIN || '*',
  trustProxy: toInt(process.env.TRUST_PROXY, 2),
  rateLimit: {
    windowMs: 60 * 1000,
    max: toInt(process.env.RATE_LIMIT_MAX, 300),
  },
  db: {
    host: process.env.DB_HOST || 'localhost',
    port: toInt(process.env.DB_PORT, 3306),
    user: process.env.DB_USER || 'expense',
    password: process.env.DB_PWD || '',
    database: process.env.DB_DATABASE || 'transactions',
    poolSize: toInt(process.env.DB_POOL_SIZE, 10),
  },
};
