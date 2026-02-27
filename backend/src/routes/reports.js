const router = require('express').Router();
const pool = require('../db/pool');
const { authenticate, requireAdmin } = require('../middleware/auth');

// GET /reports/daily?date=2024-01-15
router.get('/daily', authenticate, requireAdmin, async (req, res) => {
  const date = req.query.date || new Date().toISOString().split('T')[0];
  try {
    const summaryRes = await pool.query(
      `SELECT
         COUNT(*) AS total_bills,
         COALESCE(SUM(subtotal), 0) AS total_revenue,
         COUNT(CASE WHEN payment_method = 'cash' THEN 1 END) AS cash_bills,
         COUNT(CASE WHEN payment_method = 'upi' THEN 1 END) AS upi_bills,
         COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN subtotal ELSE 0 END), 0) AS cash_revenue,
         COALESCE(SUM(CASE WHEN payment_method = 'upi' THEN subtotal ELSE 0 END), 0) AS upi_revenue
       FROM tabs
       WHERE status = 'closed' AND DATE(closed_at) = $1`,
      [date]
    );

    const categoryRes = await pool.query(
      `SELECT
         mi.category,
         COUNT(ti.id) AS item_count,
         COALESCE(SUM(ti.subtotal), 0) AS revenue
       FROM tab_items ti
       JOIN menu_items mi ON ti.menu_item_id = mi.id
       JOIN tabs t ON ti.tab_id = t.id
       WHERE t.status = 'closed' AND DATE(t.closed_at) = $1
       GROUP BY mi.category`,
      [date]
    );

    const gameRevenueRes = await pool.query(
      `SELECT
         gs.game_name,
         COUNT(*) AS sessions,
         COALESCE(SUM(gs.duration_minutes), 0) AS total_minutes,
         COALESCE(SUM(gs.total_cost), 0) AS revenue
       FROM game_sessions gs
       JOIN tabs t ON gs.tab_id = t.id
       WHERE t.status = 'closed' AND DATE(t.closed_at) = $1
       GROUP BY gs.game_name`,
      [date]
    );

    const topItemsRes = await pool.query(
      `SELECT
         ti.menu_item_name,
         mi.category,
         SUM(ti.quantity) AS total_qty,
         SUM(ti.subtotal) AS revenue
       FROM tab_items ti
       JOIN menu_items mi ON ti.menu_item_id = mi.id
       JOIN tabs t ON ti.tab_id = t.id
       WHERE t.status = 'closed' AND DATE(t.closed_at) = $1
       GROUP BY ti.menu_item_name, mi.category
       ORDER BY total_qty DESC
       LIMIT 10`,
      [date]
    );

    res.json({
      date,
      summary: summaryRes.rows[0],
      by_category: categoryRes.rows,
      game_breakdown: gameRevenueRes.rows,
      top_items: topItemsRes.rows,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /reports/quick-items — top 6 non-game items by order frequency (for quick-add bar)
router.get('/quick-items', authenticate, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT ti.menu_item_id, ti.menu_item_name, mi.category, mi.price, mi.unit,
              SUM(ti.quantity) AS total_ordered
       FROM tab_items ti
       JOIN menu_items mi ON ti.menu_item_id = mi.id
       WHERE mi.category != 'game' AND mi.is_active = TRUE
       GROUP BY ti.menu_item_id, ti.menu_item_name, mi.category, mi.price, mi.unit
       ORDER BY total_ordered DESC
       LIMIT 6`
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /reports/range?from=2024-01-01&to=2024-01-31
router.get('/range', authenticate, requireAdmin, async (req, res) => {
  const { from, to } = req.query;
  if (!from || !to) return res.status(400).json({ error: 'from and to dates required' });

  try {
    const { rows } = await pool.query(
      `SELECT
         DATE(closed_at) AS date,
         COUNT(*) AS total_bills,
         COALESCE(SUM(subtotal), 0) AS total_revenue
       FROM tabs
       WHERE status = 'closed' AND DATE(closed_at) BETWEEN $1 AND $2
       GROUP BY DATE(closed_at)
       ORDER BY date`,
      [from, to]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
