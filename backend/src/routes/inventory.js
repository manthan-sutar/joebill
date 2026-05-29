const router = require('express').Router();
const pool = require('../db/pool');
const { authenticate, requireAdmin } = require('../middleware/auth');

// GET /inventory — stock levels (admin)
router.get('/', authenticate, requireAdmin, async (req, res) => {
  const { low_only } = req.query;
  try {
    let query = `
      SELECT *,
        (track_stock AND stock_quantity IS NOT NULL AND stock_quantity <= low_stock_threshold) AS is_low_stock
      FROM menu_items
      WHERE category != 'game'
    `;
    if (low_only === 'true') {
      query += ` AND track_stock = TRUE AND stock_quantity IS NOT NULL AND stock_quantity <= low_stock_threshold`;
    }
    query += ' ORDER BY category, name';
    const { rows } = await pool.query(query);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /inventory/:id — adjust stock or settings
router.patch('/:id', authenticate, requireAdmin, async (req, res) => {
  const { id } = req.params;
  const { stock_quantity, track_stock, low_stock_threshold, adjust_qty, note } = req.body;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const { rows: items } = await client.query('SELECT * FROM menu_items WHERE id = $1', [id]);
    if (!items.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Item not found' });
    }

    const item = items[0];
    let newQty = item.stock_quantity;

    if (adjust_qty !== undefined) {
      newQty = (item.stock_quantity ?? 0) + parseInt(adjust_qty, 10);
      if (newQty < 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({ error: 'Stock cannot go below 0' });
      }
      await client.query(
        `INSERT INTO inventory_logs (menu_item_id, change_qty, reason, note, created_by)
         VALUES ($1, $2, 'adjustment', $3, $4)`,
        [id, parseInt(adjust_qty, 10), note || null, req.user.id]
      );
    } else if (stock_quantity !== undefined) {
      newQty = parseInt(stock_quantity, 10);
    }

    const fields = [];
    const values = [];
    let idx = 1;

    if (newQty !== item.stock_quantity || stock_quantity !== undefined || adjust_qty !== undefined) {
      fields.push(`stock_quantity = $${idx++}`);
      values.push(newQty);
    }
    if (track_stock !== undefined) {
      fields.push(`track_stock = $${idx++}`);
      values.push(track_stock);
    }
    if (low_stock_threshold !== undefined) {
      fields.push(`low_stock_threshold = $${idx++}`);
      values.push(parseInt(low_stock_threshold, 10));
    }

    if (!fields.length) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'No fields to update' });
    }

    fields.push('updated_at = NOW()');
    values.push(id);

    const { rows } = await client.query(
      `UPDATE menu_items SET ${fields.join(', ')} WHERE id = $${idx} RETURNING *`,
      values
    );

    await client.query('COMMIT');
    const row = rows[0];
    row.is_low_stock =
      row.track_stock && row.stock_quantity != null && row.stock_quantity <= row.low_stock_threshold;
    res.json(row);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

module.exports = router;
