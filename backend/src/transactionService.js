'use strict';

const db = require('./db');

async function addTransaction(amount, description) {
  const result = await db.query(
    'INSERT INTO transactions (amount, description) VALUES (?, ?)',
    [amount, description],
  );
  return result.insertId;
}

async function getAllTransactions() {
  return db.query('SELECT id, amount, description FROM transactions ORDER BY id');
}

async function findTransactionById(id) {
  const rows = await db.query(
    'SELECT id, amount, description FROM transactions WHERE id = ?',
    [id],
  );
  return rows[0] || null;
}

async function deleteAllTransactions() {
  const result = await db.query('DELETE FROM transactions');
  return result.affectedRows;
}

async function deleteTransactionById(id) {
  const result = await db.query('DELETE FROM transactions WHERE id = ?', [id]);
  return result.affectedRows;
}

module.exports = {
  addTransaction,
  getAllTransactions,
  findTransactionById,
  deleteAllTransactions,
  deleteTransactionById,
};
