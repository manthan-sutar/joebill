const router = require('express').Router();
const pool = require('../db/pool');
const { authenticate, requireAdmin } = require('../middleware/auth');

function parseDateRange(query) {
  const { date, from, to } = query;
  if (from && to) {
    return { from, to, label: `${from} — ${to}`, singleDate: null };
  }
  const d = date || new Date().toISOString().split('T')[0];
  return { from: d, to: d, label: d, singleDate: d };
}

function tabFilters(range, paymentMethod) {
  const conditions = ["t.status = 'closed'", 'DATE(t.closed_at) BETWEEN $1 AND $2'];
  const params = [range.from, range.to];
  let idx = 3;
  if (paymentMethod && paymentMethod !== 'all') {
    conditions.push(`t.payment_method = $${idx++}`);
    params.push(paymentMethod);
  }
  return { where: conditions.join(' AND '), params, nextIdx: idx };
}

// GET /reports/daily?date= | ?from=&to= &payment_method=&category=
router.get('/daily', authenticate, requireAdmin, async (req, res) => {
  const range = parseDateRange(req.query);
  const paymentMethod = req.query.payment_method || 'all';
  const category = req.query.category || 'all';
  const { where, params, nextIdx } = tabFilters(range, paymentMethod);

  const categoryJoin =
    category !== 'all'
      ? `JOIN tab_items ti ON ti.tab_id = t.id JOIN menu_items mi ON ti.menu_item_id = mi.id AND mi.category = $${nextIdx}`
      : '';
  const categoryParams = category !== 'all' ? [...params, category] : params;

  try {
    let summaryRes;
    if (category !== 'all') {
      summaryRes = await pool.query(
        `SELECT
           COUNT(DISTINCT t.id) AS total_bills,
           COALESCE(SUM(ti.subtotal), 0) AS total_revenue,
           COUNT(DISTINCT CASE WHEN t.payment_method = 'cash' THEN t.id END) AS cash_bills,
           COUNT(DISTINCT CASE WHEN t.payment_method = 'upi' THEN t.id END) AS upi_bills,
           COALESCE(SUM(CASE WHEN t.payment_method = 'cash' THEN ti.subtotal ELSE 0 END), 0) AS cash_revenue,
           COALESCE(SUM(CASE WHEN t.payment_method = 'upi' THEN ti.subtotal ELSE 0 END), 0) AS upi_revenue
         FROM tabs t
         JOIN tab_items ti ON ti.tab_id = t.id
         JOIN menu_items mi ON ti.menu_item_id = mi.id AND mi.category = $${nextIdx}
         WHERE ${where}`,
        categoryParams
      );
    } else {
      summaryRes = await pool.query(
        `SELECT
           COUNT(*) AS total_bills,
           COALESCE(SUM(subtotal), 0) AS total_revenue,
           COUNT(CASE WHEN payment_method = 'cash' THEN 1 END) AS cash_bills,
           COUNT(CASE WHEN payment_method = 'upi' THEN 1 END) AS upi_bills,
           COALESCE(SUM(CASE WHEN payment_method = 'cash' THEN subtotal ELSE 0 END), 0) AS cash_revenue,
           COALESCE(SUM(CASE WHEN payment_method = 'upi' THEN subtotal ELSE 0 END), 0) AS upi_revenue
         FROM tabs t
         WHERE ${where}`,
        params
      );
    }

    const catWhere =
      category !== 'all' ? `AND mi.category = $${nextIdx}` : '';
    const catParams = category !== 'all' ? [...params, category] : params;

    const categoryRes = await pool.query(
      `SELECT
         mi.category,
         COUNT(ti.id) AS item_count,
         COALESCE(SUM(ti.subtotal), 0) AS revenue
       FROM tab_items ti
       JOIN menu_items mi ON ti.menu_item_id = mi.id
       JOIN tabs t ON ti.tab_id = t.id
       WHERE ${where} ${catWhere}
       GROUP BY mi.category`,
      catParams
    );

    const gameRes = await pool.query(
      `SELECT
         gs.game_name,
         COUNT(*) AS sessions,
         COALESCE(SUM(gs.duration_minutes), 0) AS total_minutes,
         COALESCE(SUM(gs.total_cost), 0) AS revenue
       FROM game_sessions gs
       JOIN tabs t ON gs.tab_id = t.id
       WHERE ${where}
       GROUP BY gs.game_name`,
      params
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
       WHERE ${where} ${catWhere}
       GROUP BY ti.menu_item_name, mi.category
       ORDER BY total_qty DESC
       LIMIT 10`,
      catParams
    );

    res.json({
      date: range.singleDate,
      from: range.from,
      to: range.to,
      label: range.label,
      filters: { payment_method: paymentMethod, category },
      summary: summaryRes.rows[0],
      by_category: categoryRes.rows,
      game_breakdown: category === 'all' || category === 'game' ? gameRes.rows : [],
      top_items: topItemsRes.rows,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /reports/quick-items
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

// GET /reports/range?from=&to=
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

// GET /reports/eod
router.get('/eod', authenticate, async (req, res) => {
  const date = req.query.date || new Date().toISOString().split('T')[0];
  try {
    const openTabsRes = await pool.query(
      `SELECT COUNT(*) AS open_tabs, COALESCE(SUM(subtotal), 0) AS open_total
       FROM tabs WHERE status = 'open'`
    );
    const runningGamesRes = await pool.query(
      `SELECT COUNT(*) AS running_games FROM game_sessions WHERE status = 'running'`
    );
    const overdueRes = await pool.query(
      `SELECT COUNT(*) AS overdue_tabs FROM tabs
       WHERE status = 'open' AND opened_at < NOW() - INTERVAL '3 hours'`
    );
    const settledRes = await pool.query(
      `SELECT COUNT(*) AS settled_today, COALESCE(SUM(subtotal), 0) AS revenue_today
       FROM tabs WHERE status = 'closed' AND DATE(closed_at) = $1`,
      [date]
    );
    res.json({
      date,
      open_tabs: parseInt(openTabsRes.rows[0].open_tabs, 10),
      open_total: parseFloat(openTabsRes.rows[0].open_total),
      running_games: parseInt(runningGamesRes.rows[0].running_games, 10),
      overdue_tabs: parseInt(overdueRes.rows[0].overdue_tabs, 10),
      settled_today: parseInt(settledRes.rows[0].settled_today, 10),
      revenue_today: parseFloat(settledRes.rows[0].revenue_today),
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
