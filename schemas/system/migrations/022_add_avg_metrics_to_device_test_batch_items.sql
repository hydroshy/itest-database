-- ==============================================================================
-- MIGRATION: 022_add_avg_metrics_to_device_test_batch_items.sql
-- Description: Add AVG_CYCLE, AVG_RSSI, AVG_SNR to device_test_batch_items and
--              expose them directly in system_schema.v_device_test_batch_items_detail.
-- Module: testing / device-test-batch
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Add metric columns to device_test_batch_items
ALTER TABLE system_schema."device_test_batch_items"
  ADD COLUMN IF NOT EXISTS "avg_cycle" NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS "avg_rssi" NUMERIC(10,2),
  ADD COLUMN IF NOT EXISTS "avg_snr" NUMERIC(10,2);

COMMENT ON COLUMN system_schema."device_test_batch_items"."avg_cycle" IS 'Chu kỳ nhận tin trung bình (giây) của thiết bị trong đợt test';
COMMENT ON COLUMN system_schema."device_test_batch_items"."avg_rssi" IS 'Chỉ số RSSI trung bình (dBm) của thiết bị trong đợt test';
COMMENT ON COLUMN system_schema."device_test_batch_items"."avg_snr" IS 'Chỉ số SNR trung bình (dB) của thiết bị trong đợt test';

-- 2. Update view v_device_test_batch_items_detail
DROP VIEW IF EXISTS system_schema.v_device_test_batch_items_detail CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_test_batch_items_detail AS
SELECT
  i."id",
  i."batch_id",
  b."batch_code",
  b."batch_name",
  b."item_code" AS "batch_item_code",
  b."long_fw" AS "batch_long_fw",
  b."flow_duration_seconds",
  i."device_test_registration_id",
  i."serial_number",
  i."dev_eui",
  i."item_code",
  i."fw_version",
  i."reference_device_id",
  i."reference_serial_number",
  i."reference_dev_eui",
  i."reference_device_name",
  i."status",
  i."verdict",
  i."dut_values",
  i."reference_values",
  i."comparison_result",
  i."packets_received",
  i."rules_passed",
  i."rules_failed",
  COALESCE(
    i."avg_cycle",
    (i."comparison_result"->>'avg_cycle')::numeric,
    (i."comparison_result"->>'avgCycle')::numeric,
    (i."comparison_result"->>'cycle_seconds')::numeric
  ) AS "avg_cycle",
  COALESCE(
    i."avg_rssi",
    (i."comparison_result"->>'avg_rssi')::numeric,
    (i."comparison_result"->>'avgRssi')::numeric,
    (i."comparison_result"->>'rssi')::numeric
  ) AS "avg_rssi",
  COALESCE(
    i."avg_snr",
    (i."comparison_result"->>'avg_snr')::numeric,
    (i."comparison_result"->>'avgSnr')::numeric,
    (i."comparison_result"->>'snr')::numeric
  ) AS "avg_snr",
  i."logs",
  i."created_at",
  i."updated_at"
FROM system_schema."device_test_batch_items" i
JOIN system_schema."device_test_batches" b
  ON i."batch_id" = b."id";

COMMENT ON VIEW system_schema.v_device_test_batch_items_detail IS 'Chi tiết từng thiết bị trong Test Batch kèm các chỉ số AVG_CYCLE, AVG_RSSI, AVG_SNR';

-- 3. Grant privileges
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."device_test_batch_items" TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_system_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."device_test_batch_items" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_ops_user;
  END IF;
END $$;
