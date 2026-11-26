-- ==============================================================================
-- MIGRATION: 011_fix_v_so_item_summary_wa_count_distinct.sql
-- Module: traceability-manager
-- Schema: traceability_manager
-- Description: Update v_so_item_summary view to count DISTINCT wa_number
--              instead of COUNT(wa.id) so multiple item lines under the same
--              WA do not artificially inflate the wa_count metric.
-- ==============================================================================

DROP VIEW IF EXISTS traceability_manager.v_so_item_summary CASCADE;

CREATE OR REPLACE VIEW traceability_manager.v_so_item_summary AS
WITH wa_summary AS (
  SELECT
    wa.so_id,
    COALESCE(NULLIF(TRIM(wa.item_code), ''), 'UNKNOWN') AS item_code,
    SUM(COALESCE(wa.planned_quantity, 0)) AS planned_quantity,
    COUNT(DISTINCT wa.wa_number) AS wa_count
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
  CASE
    WHEN COALESCE(w.planned_quantity, 0) > 0 THEN
      ROUND(100.0 * COALESCE(d.total_tested_serials, 0) / w.planned_quantity, 1)
    ELSE 0.0
  END AS test_progress_percent,
  CASE
    WHEN COALESCE(d.total_tested_serials, 0) > 0 THEN
      ROUND(100.0 * COALESCE(d.passed_serials, 0) / d.total_tested_serials, 1)
    ELSE 0.0
  END AS pass_rate_percent,
  d.first_tested_at,
  d.last_tested_at,
  so.created_at AS so_created_at
FROM all_items ai
JOIN traceability_manager."traceability_so" so ON so.id = ai.so_id
LEFT JOIN wa_summary w ON w.so_id = ai.so_id AND w.item_code = ai.item_code
LEFT JOIN device_summary d ON d.so_id = ai.so_id AND d.item_code = ai.item_code;

COMMENT ON VIEW traceability_manager.v_so_item_summary IS 'Metabase Analytical View: Aggregates testing progress per Sales Order and Item Code, with accurate DISTINCT wa_count.';

GRANT SELECT ON traceability_manager.v_so_item_summary TO itest_system_user;
