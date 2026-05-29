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

const VALID_CATEGORIES = ['beverage', 'drink', 'food', 'game'];
const VALID_UNITS = ['per_item', 'per_minute'];

function parseBool(val, defaultVal = false) {
  if (val === undefined || val === null || val === '') return defaultVal;
  if (typeof val === 'boolean') return val;
  const s = String(val).trim().toLowerCase();
  return ['true', '1', 'yes', 'y'].includes(s);
}

function normalizeRow(raw, rowNum) {
  const name = String(raw.name ?? '').trim();
  const category = String(raw.category ?? '').trim().toLowerCase();
  const unit = String(raw.unit ?? '').trim().toLowerCase();
  const price = parseFloat(raw.price);

  if (!name) throw new Error(`Row ${rowNum}: name is required`);
  if (!VALID_CATEGORIES.includes(category)) {
    throw new Error(`Row ${rowNum}: category must be beverage, drink, food, or game`);
  }
  if (!VALID_UNITS.includes(unit)) {
    throw new Error(`Row ${rowNum}: unit must be per_item or per_minute`);
  }
  if (Number.isNaN(price) || price < 0) {
    throw new Error(`Row ${rowNum}: price must be a non-negative number`);
  }

  const trackStock = parseBool(raw.track_stock, category !== 'game');
  let stockQty = raw.stock_quantity;
  if (stockQty !== undefined && stockQty !== null && stockQty !== '') {
    stockQty = parseInt(stockQty, 10);
    if (Number.isNaN(stockQty) || stockQty < 0) {
      throw new Error(`Row ${rowNum}: stock_quantity must be a non-negative integer`);
    }
  } else {
    stockQty = trackStock ? 0 : null;
  }

  let lowThreshold = raw.low_stock_threshold;
  if (lowThreshold !== undefined && lowThreshold !== null && lowThreshold !== '') {
    lowThreshold = parseInt(lowThreshold, 10);
    if (Number.isNaN(lowThreshold) || lowThreshold < 0) {
      throw new Error(`Row ${rowNum}: low_stock_threshold must be a non-negative integer`);
    }
  } else {
    lowThreshold = 5;
  }

  return {
    name,
    category,
    unit,
    price,
    track_stock: category === 'game' ? false : trackStock,
    stock_quantity: category === 'game' ? null : stockQty,
    low_stock_threshold: lowThreshold,
    is_active: parseBool(raw.is_active, true),
  };
}

// POST /menu-items/import — bulk import from Excel/CSV (JSON body)
// Body: { items: [{ name, category, price, unit, ... }], upsert?: boolean }
router.post('/import', authenticate, requireAdmin, async (req, res) => {
  const { items, upsert } = req.body;
  if (!Array.isArray(items) || items.length === 0) {
    return res.status(400).json({ error: 'items array is required' });
  }

  const client = await pool.connect();
  const result = { created: 0, updated: 0, errors: [] };

  try {
    await client.query('BEGIN');

    for (let i = 0; i < items.length; i++) {
      const rowNum = i + 2;
      try {
        const row = normalizeRow(items[i], rowNum);

        if (upsert) {
          const existing = await client.query(
            `SELECT id FROM menu_items WHERE LOWER(TRIM(name)) = LOWER(TRIM($1)) AND category = $2`,
            [row.name, row.category]
          );
          if (existing.rows.length) {
            await client.query(
              `UPDATE menu_items SET
                 price = $1, unit = $2, track_stock = $3, stock_quantity = $4,
                 low_stock_threshold = $5, is_active = $6, updated_at = NOW()
               WHERE id = $7`,
              [
                row.price,
                row.unit,
                row.track_stock,
                row.stock_quantity,
                row.low_stock_threshold,
                row.is_active,
                existing.rows[0].id,
              ]
            );
            result.updated++;
            continue;
          }
        }

        await client.query(
          `INSERT INTO menu_items
             (name, category, price, unit, track_stock, stock_quantity, low_stock_threshold, is_active)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
          [
            row.name,
            row.category,
            row.price,
            row.unit,
            row.track_stock,
            row.stock_quantity,
            row.low_stock_threshold,
            row.is_active,
          ]
        );
        result.created++;
      } catch (err) {
        result.errors.push({ row: rowNum, error: err.message });
      }
    }

    if (result.errors.length && !result.created && !result.updated) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Import failed', ...result });
    }

    await client.query('COMMIT');
    res.json(result);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
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
