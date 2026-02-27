-- Migration v2: customers table + phone on tabs

CREATE TABLE IF NOT EXISTS customers (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(20),
  visit_count INTEGER DEFAULT 0,
  last_visit TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_customers_name ON customers (LOWER(name));

-- Add customer_id and phone to tabs (safe to run multiple times)
ALTER TABLE tabs ADD COLUMN IF NOT EXISTS customer_id INTEGER REFERENCES customers(id);
ALTER TABLE tabs ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(20);
