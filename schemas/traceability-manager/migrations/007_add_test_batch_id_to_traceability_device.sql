-- ==============================================================================
-- MIGRATION: 007_add_test_batch_id_to_traceability_device.sql
-- Description: Add test_batch_id to traceability_manager.traceability_device and
--              update v_device_test_metrics_report & v_device_traceability_lifecycle
--              to expose test_batch_id for testing re-runs and traceability linkage.
-- Module: traceability-manager / device-traceability
-- Schema: traceability_manager
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO traceability_manager, public;

-- 1. Add column test_batch_id to traceability_device table
ALTER TABLE traceability_manager."traceability_device"
  ADD COLUMN IF NOT EXISTS "test_batch_id" UUID;

COMMENT ON COLUMN traceability_manager."traceability_device"."test_batch_id"
  IS 'Khóa ngoại / UUID của Device Test Batch (system_schema.device_test_batches.id) gán với thiết bị';

-- 2. Index on test_batch_id for high-speed batch lookups & re-tests
CREATE INDEX IF NOT EXISTS "idx_traceability_device_test_batch_id"
  ON traceability_manager."traceability_device" ("test_batch_id");

-- 3. Drop and recreate view v_device_test_metrics_report with test_batch_id
DROP VIEW IF EXISTS traceability_manager.v_device_test_metrics_report CASCADE;
CREATE OR REPLACE VIEW traceability_manager.v_device_test_metrics_report AS
SELECT
  d.id AS device_id,
  d.serial_number,
  d.dev_eui,
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
  -- Tolerance comparison against golden reference
  COALESCE(
    (d.test_raw_data->'comparison'->>'tolerance_pass')::boolean,
    (d.test_raw_data->>'tolerance_pass')::boolean
  ) AS tolerance_pass,
  (d.test_raw_data->'comparison'->>'temp_delta')::numeric AS temp_delta,
  (d.test_raw_data->'comparison'->>'hum_delta')::numeric AS hum_delta,
  -- Raw data and packet timeline payloads
  COALESCE(d.test_raw_data->'comparison'->'dut_packets', '[]'::jsonb) AS dut_packets,
  COALESCE(d.test_raw_data->'comparison'->'reference_packets', '[]'::jsonb) AS reference_packets,
  d.test_raw_data,
  d.status,
  d.created_at,
  d.updated_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_so so ON d.so_id = so.id
LEFT JOIN traceability_manager.traceability_wa wa ON d.wa_id = wa.id;

COMMENT ON VIEW traceability_manager.v_device_test_metrics_report IS 'Báo cáo chi tiết metrics kiểm thử thiết bị (AVG_CYCLE, AVG_RSSI, AVG_SNR, dung sai chuẩn, timeline gói tin, test_batch_id) cho Device Traceability';

-- 4. Recreate view v_device_traceability_lifecycle with test_batch_id
DROP VIEW IF EXISTS traceability_manager.v_device_traceability_lifecycle CASCADE;
CREATE OR REPLACE VIEW traceability_manager.v_device_traceability_lifecycle AS
SELECT
  d.id AS device_id,
  d.serial_number,
  d.device_key,
  d.dev_eui,
  d.item_code,
  d.sku,
  d.hw_version,
  d.fw_version,
  d.test_result,
  d.test_id,
  d.test_batch_id,
  d.test_station,
  d.test_person,
  d.tested_at,
  d.final_config_session_id,
  d.config_status,
  d.status AS device_status,
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  wa.id AS wa_id,
  wa.wa_number,
  wa.planned_quantity AS wa_planned_quantity,
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
    (d.test_raw_data->>'packets_received')::int
  ) AS packets_received,
  COALESCE(
    (d.test_raw_data->'comparison'->>'tolerance_pass')::boolean,
    (d.test_raw_data->>'tolerance_pass')::boolean
  ) AS tolerance_pass,
  d.test_raw_data,
  d.created_at,
  d.updated_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_so so ON d.so_id = so.id
LEFT JOIN traceability_manager.traceability_wa wa ON d.wa_id = wa.id;

COMMENT ON VIEW traceability_manager.v_device_traceability_lifecycle IS 'View tổng hợp vòng đời thiết bị: SO -> WA -> Device Unit -> Test Results -> Final Config';

-- 5. Grant runtime permissions
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
