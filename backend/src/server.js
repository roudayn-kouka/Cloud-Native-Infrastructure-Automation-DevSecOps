'use strict';

const config = require('./config');
const logger = require('./logger');
const db = require('./db');
const transactions = require('./transactionService');
const { createApp } = require('./app');

if (config.env === 'production' && !config.db.password) {
  logger.error('DB_PWD is not set; refusing to start');
  process.exit(1);
}

const app = createApp({ transactions, db, logger });
const server = app.listen(config.port, () => {
  logger.info('server started', { port: config.port, env: config.env });
});

// Initialise the schema in the background with retries so /health answers
// immediately while /ready only turns green once the database is reachable.
async function initSchema(maxAttempts = 30) {
  for (let attempt = 1; attempt <= maxAttempts; attempt += 1) {
    try {
      await db.ensureSchema();
      app.locals.setSchemaReady(true);
      logger.info('database schema ready');
      return;
    } catch (err) {
      logger.warn('database not ready yet', { attempt, error: err.message });
      await new Promise((resolve) => setTimeout(resolve, Math.min(attempt * 1000, 10000)));
    }
  }
  logger.error('could not initialise database schema; exiting');
  process.exit(1);
}
initSchema();

function shutdown(signal) {
  logger.info('shutting down', { signal });
  const force = setTimeout(() => process.exit(1), 10000);
  force.unref();
  server.close(async () => {
    await db.close();
    process.exit(0);
  });
}
process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
