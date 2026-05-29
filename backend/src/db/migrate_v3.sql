-- Migration v3: force password change flag
ALTER TABLE users ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN DEFAULT FALSE;

-- Default admin should change password on first login
UPDATE users SET must_change_password = TRUE WHERE username = 'admin';
