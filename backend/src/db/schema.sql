-- Joe's Corner Billing Database Schema

CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  username VARCHAR(50) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  role VARCHAR(10) NOT NULL CHECK (role IN ('admin', 'staff')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- category: beverage, drink, food, game
-- unit: per_item, per_minute
CREATE TABLE IF NOT EXISTS menu_items (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  category VARCHAR(20) NOT NULL CHECK (category IN ('beverage', 'drink', 'food', 'game')),
  price NUMERIC(10, 2) NOT NULL,
  unit VARCHAR(20) NOT NULL CHECK (unit IN ('per_item', 'per_minute')),
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- status: open, closed
-- payment_method: cash, upi
CREATE TABLE IF NOT EXISTS tabs (
  id SERIAL PRIMARY KEY,
  customer_name VARCHAR(100) NOT NULL,
  opened_at TIMESTAMPTZ DEFAULT NOW(),
  closed_at TIMESTAMPTZ,
  status VARCHAR(10) NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  payment_method VARCHAR(10) CHECK (payment_method IN ('cash', 'upi')),
  subtotal NUMERIC(10, 2) DEFAULT 0,
  created_by INTEGER REFERENCES users(id),
  notes TEXT
);

CREATE TABLE IF NOT EXISTS tab_items (
  id SERIAL PRIMARY KEY,
  tab_id INTEGER NOT NULL REFERENCES tabs(id) ON DELETE CASCADE,
  menu_item_id INTEGER NOT NULL REFERENCES menu_items(id),
  menu_item_name VARCHAR(100) NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price NUMERIC(10, 2) NOT NULL,
  subtotal NUMERIC(10, 2) NOT NULL,
  added_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS game_sessions (
  id SERIAL PRIMARY KEY,
  tab_id INTEGER NOT NULL REFERENCES tabs(id) ON DELETE CASCADE,
  menu_item_id INTEGER NOT NULL REFERENCES menu_items(id),
  game_name VARCHAR(100) NOT NULL,
  rate_per_minute NUMERIC(10, 2) NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  duration_minutes NUMERIC(10, 2),
  total_cost NUMERIC(10, 2),
  status VARCHAR(10) NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'stopped'))
);

-- Seed default admin user (password: admin123)
INSERT INTO users (name, username, password_hash, role)
VALUES ('Admin', 'admin', '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'admin')
ON CONFLICT (username) DO NOTHING;

-- Seed default menu items
INSERT INTO menu_items (name, category, price, unit) VALUES
  ('Coca Cola', 'beverage', 60, 'per_item'),
  ('Pepsi', 'beverage', 60, 'per_item'),
  ('Sprite', 'beverage', 60, 'per_item'),
  ('Water Bottle', 'beverage', 20, 'per_item'),
  ('Red Bull', 'beverage', 150, 'per_item'),
  ('Beer (Kingfisher)', 'drink', 120, 'per_item'),
  ('Beer (Budweiser)', 'drink', 150, 'per_item'),
  ('Whiskey (30ml)', 'drink', 80, 'per_item'),
  ('Rum (30ml)', 'drink', 70, 'per_item'),
  ('Vodka (30ml)', 'drink', 80, 'per_item'),
  ('Sandwich', 'food', 80, 'per_item'),
  ('Burger', 'food', 120, 'per_item'),
  ('French Fries', 'food', 80, 'per_item'),
  ('Nachos', 'food', 100, 'per_item'),
  ('Pizza Slice', 'food', 90, 'per_item'),
  ('Pool', 'game', 2.50, 'per_minute'),
  ('Snooker', 'game', 3.30, 'per_minute'),
  ('Darts', 'game', 1.50, 'per_minute'),
  ('Foosball', 'game', 1.00, 'per_minute')
ON CONFLICT DO NOTHING;
