-- Migration v4: inventory tracking on menu items

ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS stock_quantity INTEGER;
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS track_stock BOOLEAN DEFAULT FALSE;
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS low_stock_threshold INTEGER DEFAULT 5;

CREATE TABLE IF NOT EXISTS inventory_logs (
  id SERIAL PRIMARY KEY,
  menu_item_id INTEGER NOT NULL REFERENCES menu_items(id),
  change_qty INTEGER NOT NULL,
  reason VARCHAR(50) NOT NULL,
  note TEXT,
  created_by INTEGER REFERENCES users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default stock for common beverages/food (games unlimited)
UPDATE menu_items SET track_stock = TRUE, stock_quantity = 50, low_stock_threshold = 10
WHERE category IN ('beverage', 'drink', 'food') AND stock_quantity IS NULL;
