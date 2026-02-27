const router = require('express').Router();
const pool = require('../db/pool');
const { authenticate, requireAdmin } = require('../middleware/auth');

// GET /menu-items?category=food  — active items for ordering
router.get('/', authenticate, async (req, res) => {
  const { category } = req.query;
  try {
    let query = 'SELECT * FROM menu_items WHERE is_active = TRUE';
    const params = [];
    if (category) {
      query += ' AND category = $1';
      params.push(category);
    }
    query += ' ORDER BY category, name';
    const { rows } = await pool.query(query, params);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /menu-items/all — all items including disabled (admin settings)
router.get('/all', authenticate, requireAdmin, async (req, res) => {
  try {
    const { rows } = await pool.query('SELECT * FROM menu_items ORDER BY category, name');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /menu-items (admin only)
router.post('/', authenticate, requireAdmin, async (req, res) => {
  const { name, category, price, unit } = req.body;
  if (!name || !category || price === undefined || !unit)
    return res.status(400).json({ error: 'name, category, price, unit required' });

  try {
    const { rows } = await pool.query(
      'INSERT INTO menu_items (name, category, price, unit) VALUES ($1, $2, $3, $4) RETURNING *',
      [name, category, parseFloat(price), unit]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /menu-items/:id (admin only)
router.patch('/:id', authenticate, requireAdmin, async (req, res) => {
  const { name, category, price, unit, is_active } = req.body;
  const { id } = req.params;

  const fields = [];
  const values = [];
  let idx = 1;

  if (name !== undefined) { fields.push(`name = $${idx++}`); values.push(name); }
  if (category !== undefined) { fields.push(`category = $${idx++}`); values.push(category); }
  if (price !== undefined) { fields.push(`price = $${idx++}`); values.push(parseFloat(price)); }
  if (unit !== undefined) { fields.push(`unit = $${idx++}`); values.push(unit); }
  if (is_active !== undefined) { fields.push(`is_active = $${idx++}`); values.push(is_active); }

  if (!fields.length) return res.status(400).json({ error: 'No fields to update' });

  fields.push(`updated_at = NOW()`);
  values.push(id);

  try {
    const { rows } = await pool.query(
      `UPDATE menu_items SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
      values
    );
    if (!rows.length) return res.status(404).json({ error: 'Item not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
