-- ==============================================================================
-- MIGRATION: 004_add_partner_email_to_traceability_so.sql
-- Module: traceability-manager
-- Schema: traceability_manager
-- Description: Add partner_email and customer_email columns to traceability_so
--              and update analytical views to expose partner_email.
-- ==============================================================================

-- 1. Add email columns to traceability_so
ALTER TABLE traceability_manager."traceability_so"
  ADD COLUMN IF NOT EXISTS "partner_email" VARCHAR(255);

ALTER TABLE traceability_manager."traceability_so"
  ADD COLUMN IF NOT EXISTS "customer_email" VARCHAR(255);

COMMENT ON COLUMN traceability_manager."traceability_so"."partner_email" IS 'Email của đối tác / khách hàng liên hệ từ SO (DIS partner_email)';
COMMENT ON COLUMN traceability_manager."traceability_so"."customer_email" IS 'Alias email khách hàng (tương thích ngược)';

-- 2. Update analytical view v_so_item_summary
CREATE OR REPLACE VIEW traceability_manager.v_so_item_summary AS
SELECT
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  so.partner_email,
  COALESCE(d.item_code, 'UNKNOWN') AS item_code,
  COUNT(d.id) AS total_tested_serials,
  COUNT(d.id) FILTER (WHERE d.test_result = 'PASS') AS passed_serials,
  COUNT(d.id) FILTER (WHERE d.test_result = 'FAIL') AS failed_serials,
  MIN(d.tested_at) AS first_tested_at,
  MAX(d.tested_at) AS last_tested_at
FROM traceability_manager."traceability_so" so
JOIN traceability_manager."traceability_device" d ON d.so_id = so.id
GROUP BY so.id, so.so_number, so.customer_name, so.partner_email, COALESCE(d.item_code, 'UNKNOWN');

-- 3. Grants for runtime roles
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_item_summary TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_item_summary TO itest_plugin_user;
  END IF;
END $$;
