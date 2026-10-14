import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  addExpense,
  checkHealth,
  deleteAllExpenses,
  deleteExpense,
  listExpenses,
} from './api.js';

const numberFormat = new Intl.NumberFormat('en-US');

export default function App() {
  const [expenses, setExpenses] = useState([]);
  const [amount, setAmount] = useState('');
  const [desc, setDesc] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [online, setOnline] = useState(null);

  const total = useMemo(() => expenses.reduce((sum, e) => sum + e.amount, 0), [expenses]);

  const refresh = useCallback(async () => {
    try {
      setExpenses(await listExpenses());
      setError('');
    } catch (err) {
      setError(`Could not load expenses: ${err.message}`);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    refresh();
    const ping = () => checkHealth().then(setOnline);
    ping();
    const timer = setInterval(ping, 15000);
    return () => clearInterval(timer);
  }, [refresh]);

  async function run(action) {
    setBusy(true);
    try {
      await action();
      await refresh();
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  }

  function handleSubmit(event) {
    event.preventDefault();
    const value = Number(amount);
    if (!Number.isInteger(value)) {
      setError('Amount must be a whole number.');
      return;
    }
    run(async () => {
      await addExpense(value, desc.trim());
      setAmount('');
      setDesc('');
    });
  }

  function handleClearAll() {
    if (window.confirm('Delete ALL expenses? This cannot be undone.')) {
      run(deleteAllExpenses);
    }
  }

  return (
    <main className="container">
      <header className="header">
        <h1>Expense Tracker</h1>
        <span
          className={`status ${online === null ? 'unknown' : online ? 'up' : 'down'}`}
          role="status"
          aria-live="polite"
        >
          API {online === null ? 'checking…' : online ? 'online' : 'offline'}
        </span>
      </header>

      <section className="card summary" aria-label="Summary">
        <span>Total spent</span>
        <strong data-testid="total">{numberFormat.format(total)}</strong>
        <span className="muted">{expenses.length} expense{expenses.length === 1 ? '' : 's'}</span>
      </section>

      {error && (
        <div className="alert" role="alert">
          <span>{error}</span>
          <button type="button" className="link" onClick={() => setError('')}>
            Dismiss
          </button>
        </div>
      )}

      <form className="card form" onSubmit={handleSubmit}>
        <label>
          Amount
          <input
            type="number"
            inputMode="numeric"
            step="1"
            required
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="e.g. 25"
          />
        </label>
        <label className="grow">
          Description
          <input
            type="text"
            required
            maxLength={255}
            value={desc}
            onChange={(e) => setDesc(e.target.value)}
            placeholder="e.g. Groceries"
          />
        </label>
        <button type="submit" disabled={busy}>
          Add expense
        </button>
      </form>

      <section className="card" aria-label="Expenses">
        <div className="list-header">
          <h2>Expenses</h2>
          <button type="button" className="danger" onClick={handleClearAll} disabled={busy || expenses.length === 0}>
            Clear all
          </button>
        </div>
        {loading ? (
          <p className="muted">Loading…</p>
        ) : expenses.length === 0 ? (
          <p className="muted">No expenses yet. Add your first one above.</p>
        ) : (
          <ul className="list">
            {expenses.map((e) => (
              <li key={e.id}>
                <span className="desc">{e.description}</span>
                <span className="amount">{numberFormat.format(e.amount)}</span>
                <button
                  type="button"
                  className="link danger"
                  aria-label={`Delete ${e.description}`}
                  onClick={() => run(() => deleteExpense(e.id))}
                  disabled={busy}
                >
                  Delete
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      <footer className="footer muted">
        Cloud-Native DevOps Project · built by Roudayna Kouka
      </footer>
    </main>
  );
}
