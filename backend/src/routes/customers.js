const router = require('express').Router();
const pool = require('../db/pool');
const { authenticate } = require('../middleware/auth');

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
