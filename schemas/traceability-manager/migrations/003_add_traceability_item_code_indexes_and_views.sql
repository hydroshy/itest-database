-- ==============================================================================
-- MIGRATION: 003_add_traceability_item_code_indexes_and_views.sql
-- Module: traceability-manager
-- Schema: traceability_manager
-- Description: Composite index for SO -> ITEM-CODE lookups and analytical summary
--              view v_so_item_summary for fast tree generation (SO -> ITEM-CODE -> SERIALS).
-- ==============================================================================

-- 1. Index on traceability_device for item_code and composite (so_id, item_code)
CREATE INDEX IF NOT EXISTS idx_traceability_device_item_code
  ON traceability_manager."traceability_device" ("item_code");

CREATE INDEX IF NOT EXISTS idx_traceability_device_so_item
  ON traceability_manager."traceability_device" ("so_id", "item_code");

-- 2. Analytical view for SO -> ITEM-CODE aggregation
CREATE OR REPLACE VIEW traceability_manager.v_so_item_summary AS
SELECT
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  COALESCE(d.item_code, 'UNKNOWN') AS item_code,
  COUNT(d.id) AS total_tested_serials,
  COUNT(d.id) FILTER (WHERE d.test_result = 'PASS') AS passed_serials,
  COUNT(d.id) FILTER (WHERE d.test_result = 'FAIL') AS failed_serials,
  MIN(d.tested_at) AS first_tested_at,
  MAX(d.tested_at) AS last_tested_at
FROM traceability_manager."traceability_so" so
JOIN traceability_manager."traceability_device" d ON d.so_id = so.id
GROUP BY so.id, so.so_number, so.customer_name, COALESCE(d.item_code, 'UNKNOWN');

-- 3. Grants for itest_system_user and itest_plugin_user
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_item_summary TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_item_summary TO itest_plugin_user;
  END IF;
END $$;
