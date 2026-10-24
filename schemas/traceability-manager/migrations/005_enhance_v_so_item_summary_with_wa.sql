-- ==============================================================================
-- MIGRATION: 005_enhance_v_so_item_summary_with_wa.sql
-- Module: traceability-manager
-- Schema: traceability_manager
-- Description: Enhance analytical view v_so_item_summary to aggregate ITEM-CODE
--              from both Work Authorizations (traceability_wa) and Devices (traceability_device).
--              Ensures newly synced SOs from DIS with WAs but no devices yet
--              immediately present their ITEM-CODE and planned quantities in analytical queries.
-- ==============================================================================

DROP VIEW IF EXISTS traceability_manager.v_so_item_summary CASCADE;

CREATE OR REPLACE VIEW traceability_manager.v_so_item_summary AS
WITH wa_summary AS (
  SELECT
    wa.so_id,
    COALESCE(NULLIF(TRIM(wa.item_code), ''), 'UNKNOWN') AS item_code,
    SUM(COALESCE(wa.planned_quantity, 0)) AS planned_quantity,
    COUNT(wa.id) AS wa_count
  FROM traceability_manager."traceability_wa" wa
  GROUP BY wa.so_id, COALESCE(NULLIF(TRIM(wa.item_code), ''), 'UNKNOWN')
),
device_summary AS (
  SELECT
    d.so_id,
    COALESCE(NULLIF(TRIM(d.item_code), ''), 'UNKNOWN') AS item_code,
    COUNT(d.id) AS total_tested_serials,
    COUNT(d.id) FILTER (WHERE d.test_result = 'PASS') AS passed_serials,
    COUNT(d.id) FILTER (WHERE d.test_result = 'FAIL') AS failed_serials,
    COUNT(d.id) FILTER (WHERE d.test_result = 'PENDING') AS pending_serials,
    MIN(d.tested_at) AS first_tested_at,
    MAX(d.tested_at) AS last_tested_at
  FROM traceability_manager."traceability_device" d
  GROUP BY d.so_id, COALESCE(NULLIF(TRIM(d.item_code), ''), 'UNKNOWN')
),
all_items AS (
  SELECT so_id, item_code FROM wa_summary
  UNION
  SELECT so_id, item_code FROM device_summary
)
SELECT
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  so.partner_email,
  ai.item_code,
  COALESCE(w.planned_quantity, 0) AS planned_quantity,
  COALESCE(w.wa_count, 0) AS wa_count,
  COALESCE(d.total_tested_serials, 0) AS total_tested_serials,
  COALESCE(d.passed_serials, 0) AS passed_serials,
  COALESCE(d.failed_serials, 0) AS failed_serials,
  COALESCE(d.pending_serials, 0) AS pending_serials,
  d.first_tested_at,
  d.last_tested_at
FROM all_items ai
JOIN traceability_manager."traceability_so" so ON so.id = ai.so_id
LEFT JOIN wa_summary w ON w.so_id = ai.so_id AND w.item_code = ai.item_code
LEFT JOIN device_summary d ON d.so_id = ai.so_id AND d.item_code = ai.item_code;

COMMENT ON VIEW traceability_manager.v_so_item_summary IS 'Analytical View for Tree Structure: Aggregates item codes, planned quantities, serial counts and test results across both Work Authorizations and Devices grouped by SO, Partner Email, and Item Code.';

-- Grants for runtime roles on v_so_item_summary
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_item_summary TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_item_summary TO itest_plugin_user;
  END IF;
END $$;
