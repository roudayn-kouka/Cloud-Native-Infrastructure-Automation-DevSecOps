'use strict';

const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');

const config = require('./config');
const { createMetrics } = require('./metrics');

const MAX_AMOUNT = 1_000_000_000;

function parseAmount(value) {
  const n = typeof value === 'string' && value.trim() !== '' ? Number(value) : value;
  if (!Number.isInteger(n) || Math.abs(n) > MAX_AMOUNT) return null;
  return n;
}

function parseId(value) {
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : null;
}

/**
 * Build the Express application.
 * @param {{transactions: object, db: object, logger: object, rateLimitMax?: number|false}} deps
 */
function createApp({ transactions, db, logger, rateLimitMax = config.rateLimit.max }) {
  const app = express();
  const metrics = createMetrics();
  let schemaReady = false;

  app.disable('x-powered-by');
  app.set('trust proxy', config.trustProxy);
  app.use(helmet());
  app.use(cors({ origin: config.corsOrigin }));
  app.use(express.json({ limit: '10kb' }));
  app.use(express.urlencoded({ extended: false, limit: '10kb' }));
  app.use(metrics.middleware);

  // ---- Operational endpoints (not rate limited) -------------------------
  app.get('/health', (_req, res) => res.json({ status: 'ok' }));

  app.get('/ready', async (_req, res) => {
    try {
      if (!schemaReady) throw new Error('schema not initialised');
      await db.ping();
      metrics.dbUp.set(1);
      res.json({ status: 'ready' });
    } catch (err) {
      metrics.dbUp.set(0);
      logger.warn('readiness check failed', { error: err.message });
      res.status(503).json({ status: 'unavailable' });
    }
  });

  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', metrics.register.contentType);
    res.end(await metrics.register.metrics());
  });

  // ---- Business API ---------------------------------------------------------
  const router = express.Router();

  router.post('/', async (req, res, next) => {
    try {
      const amount = parseAmount(req.body.amount);
      const raw = req.body.desc ?? req.body.description;
      const description = typeof raw === 'string' ? raw.trim() : '';
      const errors = [];
      if (amount === null) errors.push('amount must be an integer between -1000000000 and 1000000000');
      if (description.length < 1 || description.length > 255) {
        errors.push('desc must be a non-empty string of at most 255 characters');
      }
      if (errors.length) return res.status(400).json({ message: 'invalid payload', errors });

      const id = await transactions.addTransaction(amount, description);
      logger.info('expense added', { id, amount });
      return res.status(201).json({ message: 'added transaction successfully', id });
    } catch (err) {
      return next(err);
    }
  });

  router.get('/', async (_req, res, next) => {
    try {
      const rows = await transactions.getAllTransactions();
      res.json({
        result: rows.map((r) => ({ id: r.id, amount: r.amount, description: r.description })),
      });
    } catch (err) {
      next(err);
    }
  });

  router.delete('/', async (_req, res, next) => {
    try {
      const deleted = await transactions.deleteAllTransactions();
      logger.info('all expenses deleted', { deleted });
      res.json({ message: 'all transactions deleted', deleted });
    } catch (err) {
      next(err);
    }
  });

  router.get('/:id', async (req, res, next) => {
    try {
      const id = parseId(req.params.id);
      if (id === null) return res.status(400).json({ message: 'id must be a positive integer' });
      const row = await transactions.findTransactionById(id);
      if (!row) return res.status(404).json({ message: `transaction ${id} not found` });
      return res.json({ id: row.id, amount: row.amount, description: row.description });
    } catch (err) {
      return next(err);
    }
  });

  router.delete('/:id', async (req, res, next) => {
    try {
      const id = parseId(req.params.id);
      if (id === null) return res.status(400).json({ message: 'id must be a positive integer' });
      const affected = await transactions.deleteTransactionById(id);
      if (!affected) return res.status(404).json({ message: `transaction ${id} not found` });
      logger.info('expense deleted', { id });
      return res.json({ message: `transaction ${id} deleted` });
    } catch (err) {
      return next(err);
    }
  });

  const limiter = rateLimitMax
    ? rateLimit({ windowMs: config.rateLimit.windowMs, limit: rateLimitMax, standardHeaders: true, legacyHeaders: false })
    : (_req, _res, next) => next();
  app.use('/transaction', limiter, router);

  // ---- Fallbacks --------------------------------------------------------------
  app.use((_req, res) => res.status(404).json({ message: 'not found' }));

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    if (err.type === 'entity.parse.failed') {
      return res.status(400).json({ message: 'malformed JSON body' });
    }
    logger.error('unhandled error', { error: err.message });
    return res.status(500).json({ message: 'internal server error' });
  });

  app.locals.setSchemaReady = (value) => {
    schemaReady = value;
  };

  return app;
}

module.exports = { createApp };
