'use strict';

const client = require('prom-client');

/**
 * Metrics are created per application instance (own Registry) so the app can be
 * instantiated several times, e.g. in unit tests, without duplicate registration.
 */
function createMetrics() {
  const register = new client.Registry();
  client.collectDefaultMetrics({ register });

  const httpRequests = new client.Counter({
    name: 'expense_http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status'],
    registers: [register],
  });

  const httpDuration = new client.Histogram({
    name: 'expense_http_request_duration_seconds',
    help: 'HTTP request duration in seconds',
    labelNames: ['method', 'route', 'status'],
    buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5],
    registers: [register],
  });

  const dbUp = new client.Gauge({
    name: 'expense_db_up',
    help: '1 if the last database check succeeded, 0 otherwise',
    registers: [register],
  });

  function middleware(req, res, next) {
    const end = httpDuration.startTimer();
    res.on('finish', () => {
      const route = req.route
        ? `${req.baseUrl || ''}${req.route.path}`.replace(/\/$/, '') || '/'
        : 'unmatched';
      const labels = { method: req.method, route, status: String(res.statusCode) };
      httpRequests.inc(labels);
      end(labels);
    });
    next();
  }

  return { register, middleware, dbUp };
}

module.exports = { createMetrics };
