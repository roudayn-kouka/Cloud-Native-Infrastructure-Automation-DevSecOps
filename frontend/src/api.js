// Thin client for the Expense API. All calls go through the /api prefix,
// which nginx (production) or the Vite dev server (development) forwards to the backend.
const BASE = '/api';

async function request(path, options = {}) {
  const res = await fetch(`${BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  let body = null;
  try {
    body = await res.json();
  } catch {
    // empty or non-JSON response
  }
  if (!res.ok) {
    const detail = body?.errors?.join(', ') || body?.message || res.statusText;
    throw new Error(detail || `Request failed (${res.status})`);
  }
  return body;
}

export const listExpenses = async () => (await request('/transaction')).result;

export const addExpense = (amount, desc) =>
  request('/transaction', { method: 'POST', body: JSON.stringify({ amount, desc }) });

export const deleteExpense = (id) => request(`/transaction/${id}`, { method: 'DELETE' });

export const deleteAllExpenses = () => request('/transaction', { method: 'DELETE' });

export async function checkHealth() {
  try {
    await request('/health');
    return true;
  } catch {
    return false;
  }
}
