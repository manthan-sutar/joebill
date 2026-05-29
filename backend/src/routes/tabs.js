const router = require('express').Router();
const pool = require('../db/pool');
const { authenticate } = require('../middleware/auth');

// Recalculate and update tab subtotal
async function recalcTabTotal(tabId, client) {
  const db = client || pool;
  const { rows } = await db.query(
    `SELECT
       COALESCE(SUM(ti.subtotal), 0) +
       COALESCE((SELECT SUM(gs.total_cost) FROM game_sessions gs WHERE gs.tab_id = $1 AND gs.status = 'stopped'), 0)
     AS total
     FROM tab_items ti WHERE ti.tab_id = $1`,
    [tabId]
  );
  await db.query('UPDATE tabs SET subtotal = $1 WHERE id = $2', [rows[0].total, tabId]);
  return parseFloat(rows[0].total);
}

// GET /tabs — open tabs
router.get('/', authenticate, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT t.*,
         u.name AS created_by_name,
         (SELECT COUNT(*) FROM tab_items ti WHERE ti.tab_id = t.id) AS item_count,
         (SELECT COUNT(*) FROM game_sessions gs WHERE gs.tab_id = t.id AND gs.status = 'running') AS active_games
       FROM tabs t
       LEFT JOIN users u ON t.created_by = u.id
       WHERE t.status = 'open'
       ORDER BY t.opened_at DESC`
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /tabs — create new tab
// Accepts: { customer_name, notes, customer_id?, customer_phone? }
router.post('/', authenticate, async (req, res) => {
  const { customer_name, notes, customer_id, customer_phone } = req.body;
  if (!customer_name) return res.status(400).json({ error: 'customer_name required' });

  try {
    const { rows } = await pool.query(
      'INSERT INTO tabs (customer_name, notes, created_by, customer_id, customer_phone) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [customer_name, notes || null, req.user.id, customer_id || null, customer_phone || null]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /tabs/:id — full tab detail with items and game sessions
router.get('/:id', authenticate, async (req, res) => {
  const { id } = req.params;
  try {
    const tabRes = await pool.query('SELECT * FROM tabs WHERE id = $1', [id]);
    if (!tabRes.rows.length) return res.status(404).json({ error: 'Tab not found' });

    const itemsRes = await pool.query(
      'SELECT * FROM tab_items WHERE tab_id = $1 ORDER BY added_at',
      [id]
    );
    const gamesRes = await pool.query(
      'SELECT * FROM game_sessions WHERE tab_id = $1 ORDER BY start_time',
      [id]
    );

    res.json({ ...tabRes.rows[0], items: itemsRes.rows, game_sessions: gamesRes.rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /tabs/:id — update customer name or notes
router.patch('/:id', authenticate, async (req, res) => {
  const { customer_name, notes } = req.body;
  const { id } = req.params;
  try {
    const { rows } = await pool.query(
      'UPDATE tabs SET customer_name = COALESCE($1, customer_name), notes = COALESCE($2, notes) WHERE id = $3 RETURNING *',
      [customer_name || null, notes !== undefined ? notes : null, id]
    );
    if (!rows.length) return res.status(404).json({ error: 'Tab not found' });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /tabs/:id/items — add item to tab
router.post('/:id/items', authenticate, async (req, res) => {
  const { menu_item_id, quantity } = req.body;
  const tabId = req.params.id;

  if (!menu_item_id || !quantity)
    return res.status(400).json({ error: 'menu_item_id and quantity required' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tabRes = await client.query("SELECT * FROM tabs WHERE id = $1 AND status = 'open'", [tabId]);
    if (!tabRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Open tab not found' });
    }

    const itemRes = await client.query('SELECT * FROM menu_items WHERE id = $1 AND is_active = TRUE', [menu_item_id]);
    if (!itemRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Menu item not found' });
    }

    const item = itemRes.rows[0];
    const qty = parseInt(quantity, 10);

    const { rows: existingRows } = await client.query(
      'SELECT * FROM tab_items WHERE tab_id = $1 AND menu_item_id = $2 LIMIT 1',
      [tabId, menu_item_id]
    );

    let rows;
    if (existingRows.length) {
      const existing = existingRows[0];
      const newQty = parseInt(existing.quantity, 10) + qty;
      const subtotal = parseFloat(existing.unit_price) * newQty;
      ({ rows } = await client.query(
        'UPDATE tab_items SET quantity = $1, subtotal = $2 WHERE id = $3 RETURNING *',
        [newQty, subtotal, existing.id]
      ));
    } else {
      const subtotal = parseFloat(item.price) * qty;
      ({ rows } = await client.query(
        'INSERT INTO tab_items (tab_id, menu_item_id, menu_item_name, quantity, unit_price, subtotal) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
        [tabId, menu_item_id, item.name, qty, item.price, subtotal]
      ));
    }

    await recalcTabTotal(tabId, client);
    await client.query('COMMIT');
    res.status(201).json(rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// PATCH /tabs/:id/items/:itemId — update quantity
router.patch('/:id/items/:itemId', authenticate, async (req, res) => {
  const { quantity } = req.body;
  const { id: tabId, itemId } = req.params;

  if (!quantity || quantity < 1)
    return res.status(400).json({ error: 'Valid quantity required' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const { rows: existing } = await client.query(
      'SELECT * FROM tab_items WHERE id = $1 AND tab_id = $2',
      [itemId, tabId]
    );
    if (!existing.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Item not found' });
    }

    const subtotal = parseFloat(existing[0].unit_price) * parseInt(quantity);
    const { rows } = await client.query(
      'UPDATE tab_items SET quantity = $1, subtotal = $2 WHERE id = $3 RETURNING *',
      [quantity, subtotal, itemId]
    );

    await recalcTabTotal(tabId, client);
    await client.query('COMMIT');
    res.json(rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// DELETE /tabs/:id/items/:itemId
router.delete('/:id/items/:itemId', authenticate, async (req, res) => {
  const { id: tabId, itemId } = req.params;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rowCount } = await client.query(
      'DELETE FROM tab_items WHERE id = $1 AND tab_id = $2',
      [itemId, tabId]
    );
    if (!rowCount) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Item not found' });
    }
    await recalcTabTotal(tabId, client);
    await client.query('COMMIT');
    res.json({ success: true });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// POST /tabs/:id/game-sessions — start a game (live timer) OR add manual entry
// For live timer: { menu_item_id }
// For manual entry: { menu_item_id, duration_minutes }
router.post('/:id/game-sessions', authenticate, async (req, res) => {
  const { menu_item_id, duration_minutes } = req.body;
  const tabId = req.params.id;

  if (!menu_item_id) return res.status(400).json({ error: 'menu_item_id required' });

  const isManual = duration_minutes !== undefined && duration_minutes !== null;
  if (isManual && (isNaN(parseFloat(duration_minutes)) || parseFloat(duration_minutes) <= 0)) {
    return res.status(400).json({ error: 'duration_minutes must be a positive number' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tabRes = await client.query("SELECT * FROM tabs WHERE id = $1 AND status = 'open'", [tabId]);
    if (!tabRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Open tab not found' });
    }

    const itemRes = await client.query(
      "SELECT * FROM menu_items WHERE id = $1 AND category = 'game' AND is_active = TRUE",
      [menu_item_id]
    );
    if (!itemRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Game not found' });
    }

    const game = itemRes.rows[0];

    let rows;
    if (isManual) {
      // Insert as already-stopped session with computed cost
      const mins = parseFloat(duration_minutes);
      const totalCost = parseFloat(game.price) * mins;
      const endTime = new Date();
      const startTime = new Date(endTime.getTime() - mins * 60 * 1000);
      ({ rows } = await client.query(
        `INSERT INTO game_sessions
           (tab_id, menu_item_id, game_name, rate_per_minute, start_time, end_time, duration_minutes, total_cost, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'stopped') RETURNING *`,
        [tabId, menu_item_id, game.name, game.price, startTime, endTime, mins.toFixed(2), totalCost.toFixed(2)]
      ));
      await recalcTabTotal(tabId, client);
    } else {
      ({ rows } = await client.query(
        'INSERT INTO game_sessions (tab_id, menu_item_id, game_name, rate_per_minute, start_time) VALUES ($1, $2, $3, $4, NOW()) RETURNING *',
        [tabId, menu_item_id, game.name, game.price]
      ));
    }

    await client.query('COMMIT');
    res.status(201).json(rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// PATCH /tabs/:id/game-sessions/:sessionId — stop a game
router.patch('/:id/game-sessions/:sessionId', authenticate, async (req, res) => {
  const { id: tabId, sessionId } = req.params;

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const { rows: sessions } = await client.query(
      "SELECT * FROM game_sessions WHERE id = $1 AND tab_id = $2 AND status = 'running'",
      [sessionId, tabId]
    );
    if (!sessions.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Running game session not found' });
    }

    const session = sessions[0];
    const endTime = new Date();
    const durationMs = endTime - new Date(session.start_time);
    const durationMinutes = durationMs / 60000;
    const totalCost = parseFloat(session.rate_per_minute) * durationMinutes;

    const { rows } = await client.query(
      `UPDATE game_sessions
       SET end_time = $1, duration_minutes = $2, total_cost = $3, status = 'stopped'
       WHERE id = $4 RETURNING *`,
      [endTime, durationMinutes.toFixed(2), totalCost.toFixed(2), sessionId]
    );

    await recalcTabTotal(tabId, client);
    await client.query('COMMIT');
    res.json(rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

// POST /tabs/:id/settle — close tab and record payment
router.post('/:id/settle', authenticate, async (req, res) => {
  const { payment_method, confirm_running_games } = req.body;
  const tabId = req.params.id;

  if (!['cash', 'upi'].includes(payment_method))
    return res.status(400).json({ error: 'payment_method must be cash or upi' });

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const tabRes = await client.query("SELECT * FROM tabs WHERE id = $1 AND status = 'open'", [tabId]);
    if (!tabRes.rows.length) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Open tab not found' });
    }

    const { rows: runningSessions } = await client.query(
      "SELECT * FROM game_sessions WHERE tab_id = $1 AND status = 'running'",
      [tabId]
    );

    if (runningSessions.length && !confirm_running_games) {
      await client.query('ROLLBACK');
      return res.status(409).json({
        error: 'running_games',
        message: 'Stop running games before settling, or confirm to auto-stop them.',
        running_games: runningSessions.map((s) => ({
          id: s.id,
          game_name: s.game_name,
        })),
      });
    }

    // Stop any still-running game sessions
    for (const session of runningSessions) {
      const endTime = new Date();
      const durationMs = endTime - new Date(session.start_time);
      const durationMinutes = durationMs / 60000;
      const totalCost = parseFloat(session.rate_per_minute) * durationMinutes;
      await client.query(
        "UPDATE game_sessions SET end_time=$1, duration_minutes=$2, total_cost=$3, status='stopped' WHERE id=$4",
        [endTime, durationMinutes.toFixed(2), totalCost.toFixed(2), session.id]
      );
    }

    const total = await recalcTabTotal(tabId, client);

    const { rows } = await client.query(
      "UPDATE tabs SET status='closed', closed_at=NOW(), payment_method=$1, subtotal=$2 WHERE id=$3 RETURNING *",
      [payment_method, total, tabId]
    );

    const settledTab = rows[0];

    // Auto-update customer visit count if linked
    if (settledTab.customer_id) {
      await client.query(
        'UPDATE customers SET visit_count = visit_count + 1, last_visit = NOW() WHERE id = $1',
        [settledTab.customer_id]
      );
    } else {
      // Auto-create customer record from name+phone for future autocomplete
      const custName = settledTab.customer_name;
      const custPhone = settledTab.customer_phone || null;
      // Skip generic table names like "Table 1", "Bar"
      const isGeneric = /^(table\s*\d+|bar|pool table|counter)$/i.test(custName.trim());
      if (!isGeneric) {
        const existing = await client.query(
          'SELECT id FROM customers WHERE LOWER(name) = LOWER($1) LIMIT 1',
          [custName]
        );
        if (existing.rows.length) {
          await client.query(
            'UPDATE customers SET visit_count = visit_count + 1, last_visit = NOW(), phone = COALESCE($1, phone) WHERE id = $2',
            [custPhone, existing.rows[0].id]
          );
        } else {
          await client.query(
            'INSERT INTO customers (name, phone, visit_count, last_visit) VALUES ($1, $2, 1, NOW())',
            [custName, custPhone]
          );
        }
      }
    }

    // Fetch full tab for receipt
    const itemsRes = await client.query('SELECT * FROM tab_items WHERE tab_id = $1', [tabId]);
    const gamesRes = await client.query('SELECT * FROM game_sessions WHERE tab_id = $1', [tabId]);

    await client.query('COMMIT');
    res.json({ ...settledTab, items: itemsRes.rows, game_sessions: gamesRes.rows });
  } catch (err) {
    await client.query('ROLLBACK');
    res.status(500).json({ error: err.message });
  } finally {
    client.release();
  }
});

module.exports = router;
