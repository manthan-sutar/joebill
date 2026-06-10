const router = require('express').Router();
const pool = require('../db/pool');
const { authenticate } = require('../middleware/auth');

// GET /customers/credit — pending credit bills grouped by customer
router.get('/credit', authenticate, async (req, res) => {
  try {
    const { rows: bills } = await pool.query(
      `SELECT t.id, t.customer_id, t.customer_name, t.customer_phone,
              t.subtotal, t.closed_at, t.notes
       FROM tabs t
       WHERE t.status = 'closed' AND t.payment_method = 'credit'
       ORDER BY t.closed_at DESC`
    );

    const totalPending = bills.reduce((s, b) => s + parseFloat(b.subtotal), 0);
    const grouped = new Map();

    for (const bill of bills) {
      const key = bill.customer_id
        ? `id:${bill.customer_id}`
        : `name:${bill.customer_name.toLowerCase()}`;
      if (!grouped.has(key)) {
        grouped.set(key, {
          customer_id: bill.customer_id,
          customer_name: bill.customer_name,
          customer_phone: bill.customer_phone,
          credit_total: 0,
          bills: [],
        });
      }
      const entry = grouped.get(key);
      entry.credit_total += parseFloat(bill.subtotal);
      entry.bills.push({
        id: bill.id,
        subtotal: parseFloat(bill.subtotal),
        closed_at: bill.closed_at,
        notes: bill.notes,
      });
    }

    res.json({
      total_pending: totalPending,
      bill_count: bills.length,
      customers: Array.from(grouped.values()).sort(
        (a, b) => b.credit_total - a.credit_total
      ),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /customers?q=rahul  — search / autocomplete
router.get('/', authenticate, async (req, res) => {
  const { q } = req.query;
  try {
    let rows;
    if (q && q.trim()) {
      ({ rows } = await pool.query(
        `SELECT id, name, phone, visit_count, last_visit
         FROM customers
         WHERE LOWER(name) LIKE LOWER($1)
         ORDER BY visit_count DESC, name
         LIMIT 10`,
        [`%${q.trim()}%`]
      ));
    } else {
      // Return top 10 most frequent customers (for quick picker)
      ({ rows } = await pool.query(
        `SELECT id, name, phone, visit_count, last_visit
         FROM customers
         ORDER BY visit_count DESC, last_visit DESC NULLS LAST
         LIMIT 10`
      ));
    }
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /customers — create or update customer (upsert by name+phone)
router.post('/', authenticate, async (req, res) => {
  const { name, phone } = req.body;
  if (!name) return res.status(400).json({ error: 'name required' });

  try {
    // Check if customer with same name exists
    const existing = await pool.query(
      'SELECT * FROM customers WHERE LOWER(name) = LOWER($1) LIMIT 1',
      [name.trim()]
    );
    if (existing.rows.length) {
      // Update phone if provided
      const { rows } = await pool.query(
        'UPDATE customers SET phone = COALESCE($1, phone) WHERE id = $2 RETURNING *',
        [phone || null, existing.rows[0].id]
      );
      return res.json(rows[0]);
    }
    const { rows } = await pool.query(
      'INSERT INTO customers (name, phone) VALUES ($1, $2) RETURNING *',
      [name.trim(), phone || null]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /customers/:id — update phone
router.patch('/:id', authenticate, async (req, res) => {
  const { phone, name } = req.body;
  const { id } = req.params;
  try {
    const { rows } = await pool.query(
      'UPDATE customers SET name = COALESCE($1, name), phone = COALESCE($2, phone) WHERE id = $3 RETURNING *',
      [name || null, phone || null, id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Customer not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
