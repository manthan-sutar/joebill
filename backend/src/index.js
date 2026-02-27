require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const menuItemRoutes = require('./routes/menuItems');
const tabRoutes = require('./routes/tabs');
const reportRoutes = require('./routes/reports');
const customerRoutes = require('./routes/customers');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/auth', authRoutes);
app.use('/menu-items', menuItemRoutes);
app.use('/tabs', tabRoutes);
app.use('/reports', reportRoutes);
app.use('/customers', customerRoutes);

app.get('/health', (req, res) => res.json({ status: 'ok', time: new Date() }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Joe's Corner API running on port ${PORT}`);
});
