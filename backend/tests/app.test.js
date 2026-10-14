'use strict';

const request = require('supertest');
const { createApp } = require('../src/app');

const silentLogger = { info: () => {}, warn: () => {}, error: () => {}, debug: () => {} };

function build({ ready = true, dbOk = true } = {}) {
  const store = [];
  let nextId = 1;
  const transactions = {
    addTransaction: jest.fn(async (amount, description) => {
      const id = nextId++;
      store.push({ id, amount, description });
      return id;
    }),
    getAllTransactions: jest.fn(async () => [...store]),
    findTransactionById: jest.fn(async (id) => store.find((r) => r.id === id) || null),
    deleteAllTransactions: jest.fn(async () => {
      const n = store.length;
      store.length = 0;
      return n;
    }),
    deleteTransactionById: jest.fn(async (id) => {
      const i = store.findIndex((r) => r.id === id);
      if (i === -1) return 0;
      store.splice(i, 1);
      return 1;
    }),
  };
  const db = { ping: jest.fn(async () => { if (!dbOk) throw new Error('down'); }) };
  const app = createApp({ transactions, db, logger: silentLogger, rateLimitMax: false });
  app.locals.setSchemaReady(ready);
  return { app, transactions, db };
}

describe('operational endpoints', () => {
  test('GET /health returns ok', async () => {
    const { app } = build();
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  test('GET /ready is 200 when schema and DB are ok', async () => {
    const { app } = build();
    expect((await request(app).get('/ready')).status).toBe(200);
  });

  test('GET /ready is 503 when the DB is down', async () => {
    const { app } = build({ dbOk: false });
    expect((await request(app).get('/ready')).status).toBe(503);
  });

  test('GET /ready is 503 before the schema is initialised', async () => {
    const { app } = build({ ready: false });
    expect((await request(app).get('/ready')).status).toBe(503);
  });

  test('GET /metrics exposes Prometheus metrics', async () => {
    const { app } = build();
    await request(app).get('/health');
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.text).toContain('expense_http_requests_total');
    expect(res.text).toContain('expense_db_up');
  });
});

describe('transactions API', () => {
  test('POST /transaction creates an expense', async () => {
    const { app, transactions } = build();
    const res = await request(app).post('/transaction').send({ amount: 42, desc: 'Coffee' });
    expect(res.status).toBe(201);
    expect(res.body.id).toBe(1);
    expect(transactions.addTransaction).toHaveBeenCalledWith(42, 'Coffee');
  });

  test('POST /transaction accepts numeric strings and "description"', async () => {
    const { app, transactions } = build();
    const res = await request(app).post('/transaction').send({ amount: '15', description: ' Lunch ' });
    expect(res.status).toBe(201);
    expect(transactions.addTransaction).toHaveBeenCalledWith(15, 'Lunch');
  });

  test.each([
    [{ amount: 'abc', desc: 'x' }],
    [{ amount: 1.5, desc: 'x' }],
    [{ amount: 10 }],
    [{ amount: 10, desc: '   ' }],
    [{ amount: 10, desc: 'x'.repeat(256) }],
    [{ amount: 1e12, desc: 'x' }],
  ])('POST /transaction rejects invalid payload %j', async (payload) => {
    const { app, transactions } = build();
    const res = await request(app).post('/transaction').send(payload);
    expect(res.status).toBe(400);
    expect(transactions.addTransaction).not.toHaveBeenCalled();
  });

  test('POST /transaction rejects malformed JSON', async () => {
    const { app } = build();
    const res = await request(app).post('/transaction').set('Content-Type', 'application/json').send('{bad');
    expect(res.status).toBe(400);
  });

  test('SQL injection payloads are passed as plain data, never executed', async () => {
    const { app, transactions } = build();
    const evil = "x'); DROP TABLE transactions;--";
    await request(app).post('/transaction').send({ amount: 1, desc: evil });
    expect(transactions.addTransaction).toHaveBeenCalledWith(1, evil);
  });

  test('GET /transaction lists expenses', async () => {
    const { app } = build();
    await request(app).post('/transaction').send({ amount: 5, desc: 'Tea' });
    const res = await request(app).get('/transaction');
    expect(res.status).toBe(200);
    expect(res.body.result).toEqual([{ id: 1, amount: 5, description: 'Tea' }]);
  });

  test('GET /transaction/:id returns one expense or 404', async () => {
    const { app } = build();
    await request(app).post('/transaction').send({ amount: 5, desc: 'Tea' });
    expect((await request(app).get('/transaction/1')).body.description).toBe('Tea');
    expect((await request(app).get('/transaction/99')).status).toBe(404);
    expect((await request(app).get('/transaction/abc')).status).toBe(400);
  });

  test('DELETE /transaction/:id deletes or 404s', async () => {
    const { app } = build();
    await request(app).post('/transaction').send({ amount: 5, desc: 'Tea' });
    expect((await request(app).delete('/transaction/1')).status).toBe(200);
    expect((await request(app).delete('/transaction/1')).status).toBe(404);
  });

  test('DELETE /transaction removes everything', async () => {
    const { app } = build();
    await request(app).post('/transaction').send({ amount: 1, desc: 'a' });
    await request(app).post('/transaction').send({ amount: 2, desc: 'b' });
    const res = await request(app).delete('/transaction');
    expect(res.status).toBe(200);
    expect(res.body.deleted).toBe(2);
  });

  test('returns 500 without leaking internals when the service throws', async () => {
    const { app, transactions } = build();
    transactions.getAllTransactions.mockRejectedValueOnce(new Error('secret db detail'));
    const res = await request(app).get('/transaction');
    expect(res.status).toBe(500);
    expect(JSON.stringify(res.body)).not.toContain('secret db detail');
  });

  test('unknown routes return 404', async () => {
    const { app } = build();
    expect((await request(app).get('/nope')).status).toBe(404);
  });
});
