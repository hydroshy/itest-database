-- ==============================================================================
-- MIGRATION: 009_create_so_summary_and_device_summary_views.sql
-- Module: traceability-manager
-- Schema: traceability_manager
-- Description: Creates Metabase analytical tracking views:
--              1. v_so_summary: Aggregates SO, WA, and ITEM-CODE with planned,
--                 tested, remaining test, config distinct, remaining config, and progress.
--              2. v_device_summary: Comprehensive device-level tracking view
--                 exposing dev_eui, app_key, app_eui, serial_number, and lifecycle.
--              Also adds app_eui column & index to traceability_manager.traceability_device.
-- ==============================================================================

-- 1. Ensure app_eui column exists on traceability_device
ALTER TABLE traceability_manager."traceability_device"
  ADD COLUMN IF NOT EXISTS "app_eui" VARCHAR(64);

CREATE INDEX IF NOT EXISTS idx_traceability_device_app_eui
  ON traceability_manager."traceability_device"("app_eui");

-- Backfill app_eui from test_raw_data JSONB if present
UPDATE traceability_manager."traceability_device"
SET "app_eui" = COALESCE(
  app_eui,
  test_raw_data->>'app_eui',
  test_raw_data->>'appeui',
  test_raw_data->'lorawan'->>'app_eui',
  test_raw_data->'lorawan'->>'appeui',
  test_raw_data->'comparison'->>'app_eui'
)
WHERE "app_eui" IS NULL
  AND (
    test_raw_data->>'app_eui' IS NOT NULL
    OR test_raw_data->>'appeui' IS NOT NULL
    OR test_raw_data->'lorawan'->>'app_eui' IS NOT NULL
    OR test_raw_data->'lorawan'->>'appeui' IS NOT NULL
    OR test_raw_data->'comparison'->>'app_eui' IS NOT NULL
  );

-- Backfill app_eui from device_test_registrations if table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'system_schema' AND table_name = 'device_test_registrations'
  ) THEN
    UPDATE traceability_manager.traceability_device td
    SET app_eui = dtr.app_eui
    FROM system_schema.device_test_registrations dtr
    WHERE (td.serial_number = dtr.serial_number OR (td.dev_eui IS NOT NULL AND td.dev_eui = dtr.dev_eui))
      AND td.app_eui IS NULL
      AND dtr.app_eui IS NOT NULL;
  END IF;
END $$;

-- 2. Create or Replace View: v_so_summary (Metabase SO Tracking View)
DROP VIEW IF EXISTS traceability_manager.v_so_summary CASCADE;

CREATE OR REPLACE VIEW traceability_manager.v_so_summary AS
WITH wa_summary AS (
  SELECT
    wa.so_id,
    wa.id AS wa_id,
    wa.wa_number,
    COALESCE(NULLIF(TRIM(wa.item_code), ''), 'UNKNOWN') AS item_code,
    SUM(COALESCE(wa.planned_quantity, 0))::bigint AS planned_quantity
  FROM traceability_manager.traceability_wa wa
  GROUP BY wa.so_id, wa.id, wa.wa_number, COALESCE(NULLIF(TRIM(wa.item_code), ''), 'UNKNOWN')
),
device_summary AS (
  SELECT
    d.so_id,
    d.wa_id,
    COALESCE(NULLIF(TRIM(d.item_code), ''), 'UNKNOWN') AS item_code,
    COUNT(DISTINCT d.serial_number)::bigint AS tested_quantity,
    COUNT(DISTINCT d.serial_number) FILTER (WHERE d.test_result = 'PASS')::bigint AS tested_pass_quantity,
    COUNT(DISTINCT d.serial_number) FILTER (WHERE d.test_result = 'FAIL')::bigint AS tested_fail_quantity,
    COUNT(DISTINCT d.serial_number) FILTER (WHERE d.test_result = 'PENDING')::bigint AS tested_pending_quantity,
    COUNT(DISTINCT d.serial_number) FILTER (
      WHERE d.config_status IN ('CONFIGURED_PASS', 'PASS')
         OR (d.test_raw_data->'final_config_audit'->>'status' = 'PASS')
    )::bigint AS config_distinct,
    COUNT(DISTINCT d.serial_number) FILTER (
      WHERE d.config_status IN ('CONFIGURED_FAIL', 'FAIL')
         OR (d.test_raw_data->'final_config_audit'->>'status' = 'FAIL')
    )::bigint AS config_failed_distinct,
    MIN(d.tested_at) AS first_tested_at,
    MAX(d.tested_at) AS last_tested_at,
    MAX(COALESCE(d.configured_at, (d.test_raw_data->'final_config_audit'->>'saved_at')::timestamptz)) AS last_configured_at
  FROM traceability_manager.traceability_device d
  GROUP BY d.so_id, d.wa_id, COALESCE(NULLIF(TRIM(d.item_code), ''), 'UNKNOWN')
),
combined_keys AS (
  SELECT so_id, wa_id, item_code FROM wa_summary
  UNION
  SELECT so_id, wa_id, item_code FROM device_summary
)
SELECT
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  so.partner_email,
  ck.wa_id,
  COALESCE(w.wa_number, wa_ref.wa_number, '—') AS wa_number,
  ck.item_code,
  COALESCE(w.planned_quantity, 0)::bigint AS planned_quantity,
  COALESCE(d.tested_quantity, 0)::bigint AS tested,
  COALESCE(d.tested_quantity, 0)::bigint AS tested_quantity,
  COALESCE(d.tested_pass_quantity, 0)::bigint AS tested_pass_quantity,
  COALESCE(d.tested_fail_quantity, 0)::bigint AS tested_fail_quantity,
  COALESCE(d.tested_pending_quantity, 0)::bigint AS tested_pending_quantity,
  GREATEST(0, COALESCE(w.planned_quantity, 0) - COALESCE(d.tested_quantity, 0))::bigint AS remaining_test,
  COALESCE(d.config_distinct, 0)::bigint AS config_distinct,
  COALESCE(d.config_failed_distinct, 0)::bigint AS config_failed_distinct,
  GREATEST(0, COALESCE(w.planned_quantity, 0) - COALESCE(d.config_distinct, 0))::bigint AS remaining_config,
  ROUND(
    100.0 * COALESCE(d.tested_pass_quantity, 0) / NULLIF(COALESCE(w.planned_quantity, 0), 0),
    2
  ) AS test_progress_percent,
  ROUND(
    100.0 * COALESCE(d.config_distinct, 0) / NULLIF(COALESCE(w.planned_quantity, 0), 0),
    2
  ) AS config_progress_percent,
  CASE
    WHEN COALESCE(w.planned_quantity, 0) > 0 AND COALESCE(d.config_distinct, 0) >= w.planned_quantity THEN 'COMPLETED'
    WHEN COALESCE(d.config_distinct, 0) > 0 THEN 'CONFIGURING'
    WHEN COALESCE(d.tested_quantity, 0) > 0 THEN 'TESTING'
    ELSE 'PENDING'
  END AS production_status,
  d.first_tested_at,
  d.last_tested_at,
  d.last_configured_at,
  so.created_at AS so_created_at
FROM combined_keys ck
JOIN traceability_manager.traceability_so so ON so.id = ck.so_id
LEFT JOIN wa_summary w ON w.so_id = ck.so_id AND (w.wa_id = ck.wa_id OR (w.wa_id IS NULL AND ck.wa_id IS NULL)) AND w.item_code = ck.item_code
LEFT JOIN traceability_manager.traceability_wa wa_ref ON wa_ref.id = ck.wa_id
LEFT JOIN device_summary d ON d.so_id = ck.so_id AND (d.wa_id = ck.wa_id OR (d.wa_id IS NULL AND ck.wa_id IS NULL)) AND d.item_code = ck.item_code;

COMMENT ON VIEW traceability_manager.v_so_summary IS 'Metabase Analytical View: Aggregates SO, WA, and ITEM-CODE order progress including planned quantity, tested count, remaining test, config distinct, remaining config, and completion rates.';

-- 3. Create or Replace View: v_device_summary (Metabase Device Tracking View)
DROP VIEW IF EXISTS traceability_manager.v_device_summary CASCADE;

CREATE OR REPLACE VIEW traceability_manager.v_device_summary AS
SELECT
  d.id AS device_id,
  d.serial_number,
  d.dev_eui,
  COALESCE(
    d.app_eui,
    d.test_raw_data->>'app_eui',
    d.test_raw_data->>'appeui',
    d.test_raw_data->'lorawan'->>'app_eui',
    d.test_raw_data->'lorawan'->>'appeui',
    d.test_raw_data->'comparison'->>'app_eui',
    dtr.app_eui,
    '0000000000000000'
  ) AS app_eui,
  COALESCE(
    d.app_key,
    d.test_raw_data->>'app_key',
    d.test_raw_data->'final_config_audit'->>'app_key',
    dtr.app_key
  ) AS app_key,
  d.device_key,
  COALESCE(d.item_code, wa.item_code) AS item_code,
  d.sku,
  d.hw_version,
  d.fw_version,
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  so.partner_email,
  wa.id AS wa_id,
  wa.wa_number,
  d.test_result,
  d.test_id,
  d.test_station,
  d.test_person,
  d.tested_at,
  d.config_status,
  COALESCE(
    d.config_person,
    fcs.operator,
    d.test_raw_data->'final_config_audit'->>'operator',
    d.test_raw_data->'final_config_audit'->>'configured_by'
  ) AS config_person,
  COALESCE(
    d.configured_at,
    fcs.completed_at,
    (d.test_raw_data->'final_config_audit'->>'saved_at')::timestamptz
  ) AS configured_at,
  d.final_config_session_id,
  d.status AS overall_status,
  d.created_at,
  d.updated_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_so so ON d.so_id = so.id
LEFT JOIN traceability_manager.traceability_wa wa ON d.wa_id = wa.id
LEFT JOIN finalconfig_manager.finalconfig_execution_session fcs ON d.final_config_session_id = fcs.id
LEFT JOIN system_schema.device_test_registrations dtr ON d.serial_number = dtr.serial_number;

COMMENT ON VIEW traceability_manager.v_device_summary IS 'Metabase Analytical View: Comprehensive device tracking view exposing dev_eui, app_key, app_eui, serial_number, hardware test results, and final config details.';

-- 4. Runtime Grants for Metabase and application roles
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_summary TO itest_system_user;
    GRANT SELECT ON TABLE traceability_manager.v_device_summary TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_summary TO itest_plugins_user;
    GRANT SELECT ON TABLE traceability_manager.v_device_summary TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_summary TO itest_plugin_user;
    GRANT SELECT ON TABLE traceability_manager.v_device_summary TO itest_plugin_user;
  END IF;
END $$;
