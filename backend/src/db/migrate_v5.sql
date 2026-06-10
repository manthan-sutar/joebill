-- Migration v5: customer credit (pay later)

ALTER TABLE tabs DROP CONSTRAINT IF EXISTS tabs_payment_method_check;
ALTER TABLE tabs ADD CONSTRAINT tabs_payment_method_check
  CHECK (payment_method IS NULL OR payment_method IN ('cash', 'upi', 'credit'));
