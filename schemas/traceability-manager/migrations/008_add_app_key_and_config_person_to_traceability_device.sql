-- ==============================================================================
-- MIGRATION: 008_add_app_key_and_config_person_to_traceability_device.sql
-- Description: Adds dedicated columns app_key, config_person, and configured_at
--              to traceability_manager.traceability_device.
--              Backfills existing data from test_raw_data and updates
--              v_device_traceability_lifecycle & v_device_test_metrics_report
--              to expose AppKey and Final Config Operator details.
-- Module: traceability-manager / device-traceability / final-config
-- Schema: traceability_manager
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO traceability_manager, public;

-- 1. Add dedicated columns to traceability_device table
ALTER TABLE traceability_manager."traceability_device"
  ADD COLUMN IF NOT EXISTS "app_key" VARCHAR(64),
  ADD COLUMN IF NOT EXISTS "config_person" VARCHAR(100),
  ADD COLUMN IF NOT EXISTS "configured_at" TIMESTAMPTZ;

COMMENT ON COLUMN traceability_manager."traceability_device"."app_key"
  IS 'LoRaWAN AppKey bí mật (16 byte hex = 32 ký tự) đã nạp cho thiết bị qua Final Config';
COMMENT ON COLUMN traceability_manager."traceability_device"."config_person"
  IS 'Kỹ thuật viên / Người thực hiện phiên nạp cấu hình cuối cùng (Final Config Operator)';
COMMENT ON COLUMN traceability_manager."traceability_device"."configured_at"
  IS 'Thời điểm nạp hoàn tất cấu hình cuối cùng của thiết bị';

-- 2. Backfill existing data from test_raw_data JSON
UPDATE traceability_manager."traceability_device"
SET "app_key" = UPPER(COALESCE(test_raw_data->>'app_key', test_raw_data->>'appKey', test_raw_data->'final_config_audit'->>'app_key'))
WHERE "app_key" IS NULL AND (test_raw_data->>'app_key' IS NOT NULL OR test_raw_data->>'appKey' IS NOT NULL OR test_raw_data->'final_config_audit'->>'app_key' IS NOT NULL);

UPDATE traceability_manager."traceability_device"
SET "config_person" = COALESCE(test_raw_data->'final_config_audit'->>'operator', test_raw_data->'final_config_audit'->>'config_person')
WHERE "config_person" IS NULL AND (test_raw_data->'final_config_audit'->>'operator' IS NOT NULL OR test_raw_data->'final_config_audit'->>'config_person' IS NOT NULL);

UPDATE traceability_manager."traceability_device"
SET "configured_at" = (test_raw_data->'final_config_audit'->>'saved_at')::timestamptz
WHERE "configured_at" IS NULL AND test_raw_data->'final_config_audit'->>'saved_at' IS NOT NULL;

-- 3. Indexes for high-performance searching
CREATE INDEX IF NOT EXISTS "idx_traceability_device_app_key"
  ON traceability_manager."traceability_device" ("app_key");

CREATE INDEX IF NOT EXISTS "idx_traceability_device_config_person"
  ON traceability_manager."traceability_device" ("config_person");

-- 4. Recreate View v_device_traceability_lifecycle
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'traceability_manager' AND c.relname = 'v_device_traceability_lifecycle' AND c.relkind = 'v'
  ) THEN
    DROP VIEW traceability_manager.v_device_traceability_lifecycle CASCADE;
  END IF;
END $$;

CREATE OR REPLACE VIEW traceability_manager.v_device_traceability_lifecycle AS
SELECT
  d.id AS device_id,
  d.serial_number,
  d.device_key,
  d.dev_eui,
  COALESCE(d.app_key, d.test_raw_data->>'app_key', d.test_raw_data->'final_config_audit'->>'app_key') AS app_key,
  COALESCE(d.item_code, wa.item_code) AS item_code,
  d.sku,
  d.hw_version,
  d.fw_version,
  d.test_result,
  d.test_id,
  d.test_batch_id,
  d.test_station,
  d.test_person,
  d.tested_at,
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_cycle')::numeric,
    (d.test_raw_data->>'avg_cycle')::numeric,
    (d.test_raw_data->>'avgCycle')::numeric
  ) AS avg_cycle,
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_rssi')::numeric,
    (d.test_raw_data->>'avg_rssi')::numeric,
    (d.test_raw_data->>'avgRssi')::numeric
  ) AS avg_rssi,
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_snr')::numeric,
    (d.test_raw_data->>'avg_snr')::numeric,
    (d.test_raw_data->>'avgSnr')::numeric
  ) AS avg_snr,
  d.test_raw_data,
  (d.test_result = 'PASS') AS is_eligible_for_final_config,
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  so.partner_email,
  wa.id AS wa_id,
  wa.wa_number,
  d.final_config_session_id,
  d.config_status AS final_config_status,
  COALESCE(d.config_person, fcs.operator, d.test_raw_data->'final_config_audit'->>'operator') AS config_person,
  COALESCE(d.configured_at, fcs.completed_at, (d.test_raw_data->'final_config_audit'->>'saved_at')::timestamptz) AS configured_at,
  fcs.status AS final_config_session_status,
  fcs.current_step AS final_config_current_step,
  fcs.total_steps AS final_config_total_steps,
  fcs.passed_steps AS final_config_passed_steps,
  fcs.failed_steps AS final_config_failed_steps,
  fcs.started_at AS final_config_started_at,
  fcs.completed_at AS final_config_completed_at,
  fcs.error_message AS final_config_error,
  fcs.metadata AS final_config_metadata,
  d.status AS overall_status,
  d.created_at,
  d.updated_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_so so ON d.so_id = so.id
LEFT JOIN traceability_manager.traceability_wa wa ON d.wa_id = wa.id
LEFT JOIN finalconfig_manager.finalconfig_execution_session fcs ON d.final_config_session_id = fcs.id;

COMMENT ON VIEW traceability_manager.v_device_traceability_lifecycle IS 'Metabase Analytical View: Aggregates full device lifecycle spanning Sale Order (SO), Work Authorization (WA), Hardware Test CSV Results, AppKey, and Final Configuration Session with Operator.';

-- 5. Recreate View v_device_test_metrics_report with app_key, config_person, configured_at
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'traceability_manager' AND c.relname = 'v_device_test_metrics_report' AND c.relkind = 'v'
  ) THEN
    DROP VIEW traceability_manager.v_device_test_metrics_report CASCADE;
  END IF;
END $$;

CREATE OR REPLACE VIEW traceability_manager.v_device_test_metrics_report AS
SELECT
  d.id AS device_id,
  d.serial_number,
  d.dev_eui,
  COALESCE(d.app_key, d.test_raw_data->>'app_key', d.test_raw_data->'final_config_audit'->>'app_key') AS app_key,
  so.so_number,
  wa.wa_number,
  COALESCE(d.item_code, wa.item_code) AS item_code,
  d.hw_version,
  d.fw_version,
  d.test_result AS result,
  COALESCE(d.test_person, 'tester') AS tested_by,
  d.tested_at AS time_test,
  d.test_station,
  d.test_id,
  d.test_batch_id,
  d.final_config_session_id,
  d.config_status,
  COALESCE(d.config_person, d.test_raw_data->'final_config_audit'->>'operator') AS config_person,
  d.configured_at,
  -- RF Metrics extracted from test_raw_data JSON
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_cycle')::numeric,
    (d.test_raw_data->>'avg_cycle')::numeric,
    (d.test_raw_data->>'avgCycle')::numeric
  ) AS avg_cycle,
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_rssi')::numeric,
    (d.test_raw_data->>'avg_rssi')::numeric,
    (d.test_raw_data->>'avgRssi')::numeric
  ) AS avg_rssi,
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_snr')::numeric,
    (d.test_raw_data->>'avg_snr')::numeric,
    (d.test_raw_data->>'avgSnr')::numeric
  ) AS avg_snr,
  COALESCE(
    (d.test_raw_data->'comparison'->>'packets_received')::int,
    (d.test_raw_data->>'packets_received')::int,
    jsonb_array_length(COALESCE(d.test_raw_data->'comparison'->'dut_packets', '[]'::jsonb))
  ) AS packets_received,
  COALESCE(
    (d.test_raw_data->'comparison'->>'tolerance_pass')::boolean,
    (d.test_raw_data->>'tolerance_pass')::boolean
  ) AS tolerance_pass,
  (d.test_raw_data->'comparison'->>'temp_delta')::numeric AS temp_delta,
  (d.test_raw_data->'comparison'->>'hum_delta')::numeric AS hum_delta,
  COALESCE(d.test_raw_data->'comparison'->'dut_packets', '[]'::jsonb) AS dut_packets,
  COALESCE(d.test_raw_data->'comparison'->'reference_packets', '[]'::jsonb) AS reference_packets,
  d.test_raw_data,
  d.status,
  d.created_at,
  d.updated_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_so so ON d.so_id = so.id
LEFT JOIN traceability_manager.traceability_wa wa ON d.wa_id = wa.id;

COMMENT ON VIEW traceability_manager.v_device_test_metrics_report IS 'Báo cáo chi tiết metrics kiểm thử thiết bị và kết quả Final Config cho Device Traceability';

-- 6. Grant runtime permissions
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON traceability_manager.v_device_test_metrics_report TO itest_system_user;
    GRANT SELECT ON traceability_manager.v_device_traceability_lifecycle TO itest_system_user;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON traceability_manager.v_device_test_metrics_report TO itest_plugins_user;
    GRANT SELECT ON traceability_manager.v_device_traceability_lifecycle TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON traceability_manager.v_device_test_metrics_report TO itest_ops_user;
    GRANT SELECT ON traceability_manager.v_device_traceability_lifecycle TO itest_ops_user;
  END IF;
END $$;
