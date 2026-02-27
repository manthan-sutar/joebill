const router = require('express').Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db/pool');
const { authenticate, requireAdmin } = require('../middleware/auth');

// POST /auth/login
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password)
    return res.status(400).json({ error: 'Username and password required' });

  try {
    const { rows } = await pool.query(
      'SELECT * FROM users WHERE username = $1 AND is_active = TRUE',
      [username]
    );
    const user = rows[0];
    if (!user) return res.status(401).json({ error: 'Invalid credentials' });

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return res.status(401).json({ error: 'Invalid credentials' });

    const token = jwt.sign(
      { id: user.id, username: user.username, role: user.role, name: user.name },
      process.env.JWT_SECRET,
      { expiresIn: '12h' }
    );

    res.json({ token, user: { id: user.id, name: user.name, username: user.username, role: user.role } });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /auth/me
router.get('/me', authenticate, async (req, res) => {
  res.json({ user: req.user });
});

// GET /auth/users (admin only)
router.get('/users', authenticate, requireAdmin, async (req, res) => {
  try {
    const { rows } = await pool.query(
      'SELECT id, name, username, role, is_active, created_at FROM users ORDER BY created_at'
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /auth/users (admin only)
router.post('/users', authenticate, requireAdmin, async (req, res) => {
  const { name, username, password, role } = req.body;
  if (!name || !username || !password || !role)
    return res.status(400).json({ error: 'name, username, password, role required' });
  if (!['admin', 'staff'].includes(role))
    return res.status(400).json({ error: 'role must be admin or staff' });

  try {
    const hash = await bcrypt.hash(password, 10);
    const { rows } = await pool.query(
      'INSERT INTO users (name, username, password_hash, role) VALUES ($1, $2, $3, $4) RETURNING id, name, username, role, is_active',
      [name, username, hash, role]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Username already exists' });
    res.status(500).json({ error: err.message });
  }
});

// PATCH /auth/users/:id (admin only)
router.patch('/users/:id', authenticate, requireAdmin, async (req, res) => {
  const { name, password, role, is_active } = req.body;
  const { id } = req.params;

  try {
    if (password) {
      const hash = await bcrypt.hash(password, 10);
      await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [hash, id]);
    }
    const fields = [];
    const values = [];
    let idx = 1;
    if (name) { fields.push(`name = $${idx++}`); values.push(name); }
    if (role) { fields.push(`role = $${idx++}`); values.push(role); }
    if (is_active !== undefined) { fields.push(`is_active = $${idx++}`); values.push(is_active); }

    if (fields.length) {
      values.push(id);
      await pool.query(`UPDATE users SET ${fields.join(', ')} WHERE id = $${idx}`, values);
    }

    const { rows } = await pool.query(
      'SELECT id, name, username, role, is_active FROM users WHERE id = $1',
      [id]
    );
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
