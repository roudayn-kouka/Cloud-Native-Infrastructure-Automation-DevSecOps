'use strict';

jest.mock('../src/db', () => ({ query: jest.fn() }));

const db = require('../src/db');
const service = require('../src/transactionService');

beforeEach(() => db.query.mockReset());

test('addTransaction uses a parameterised INSERT and returns the new id', async () => {
  db.query.mockResolvedValue({ insertId: 7 });
  await expect(service.addTransaction(10, "O'Reilly")).resolves.toBe(7);
  const [sql, params] = db.query.mock.calls[0];
  expect(sql).toContain('VALUES (?, ?)');
  expect(sql).not.toContain("O'Reilly");
  expect(params).toEqual([10, "O'Reilly"]);
});

test('getAllTransactions selects ordered rows', async () => {
  db.query.mockResolvedValue([{ id: 1, amount: 1, description: 'a' }]);
  await expect(service.getAllTransactions()).resolves.toHaveLength(1);
  expect(db.query.mock.calls[0][0]).toContain('ORDER BY id');
});

test('findTransactionById returns the row or null', async () => {
  db.query.mockResolvedValueOnce([{ id: 3 }]).mockResolvedValueOnce([]);
  await expect(service.findTransactionById(3)).resolves.toEqual({ id: 3 });
  await expect(service.findTransactionById(4)).resolves.toBeNull();
  expect(db.query.mock.calls[0][1]).toEqual([3]);
});

test('delete helpers return affected rows', async () => {
  db.query.mockResolvedValue({ affectedRows: 2 });
  await expect(service.deleteAllTransactions()).resolves.toBe(2);
  await expect(service.deleteTransactionById(1)).resolves.toBe(2);
  expect(db.query.mock.calls[1][1]).toEqual([1]);
});
