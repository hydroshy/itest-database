-- ==============================================================================
-- MIGRATION: 023_unify_simulation_flow_autocheck_and_multi_references.sql
-- Module: testing / system
-- Schema: system_schema
-- Target: simulation_profiles, device_test_batches, device_test_batch_items,
--         v_simulation_flows, v_device_test_batches, v_device_test_batch_items_detail
-- Description:
--   1. Unify Simulation Flow and AutoCheck into simulation_profiles:
--      - Add fw_version, auto_check_criteria, reference_devices, simulator_device.
--      - Backfill fw_version from long_fw where missing.
--   2. Extend device_test_batches:
--      - Add reference_devices JSONB and simulator_device JSONB.
--   3. Extend device_test_batch_items:
--      - Add reference_devices_data JSONB (supports multi-reference devices).
--      - Add measurement window packet count fields: window_packet_count, start_counter, end_counter, reference_window_packet_count.
--      - Add avg_metrics JSONB (independent average calculations: SAMPLE_COUNT, TIME_WINDOW, MEASUREMENT_WINDOW).
--   4. Update views:
--      - v_simulation_flows: expose fw_version, auto_check_criteria, reference_devices, simulator_device, rule_count.
--      - v_device_test_batches: expose reference_devices, simulator_device.
--      - v_device_test_batch_items_detail: expose reference_devices_data, window_packet_count, start_counter, end_counter, reference_window_packet_count, avg_metrics.
--   5. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Extend simulation_profiles for unified Flow + AutoCheck & Multi-Reference
ALTER TABLE system_schema."simulation_profiles"
  ADD COLUMN IF NOT EXISTS "fw_version" VARCHAR(100),
  ADD COLUMN IF NOT EXISTS "auto_check_criteria" JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS "reference_devices" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "simulator_device" JSONB DEFAULT NULL;

-- Backfill fw_version from long_fw if missing
UPDATE system_schema."simulation_profiles"
SET "fw_version" = "long_fw"
WHERE "fw_version" IS NULL AND "long_fw" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "idx_simu_profiles_fw_version"
  ON system_schema."simulation_profiles" ("fw_version");

CREATE INDEX IF NOT EXISTS "idx_simu_profiles_auto_check_gin"
  ON system_schema."simulation_profiles" USING GIN ("auto_check_criteria");

CREATE INDEX IF NOT EXISTS "idx_simu_profiles_ref_devices_gin"
  ON system_schema."simulation_profiles" USING GIN ("reference_devices");

COMMENT ON COLUMN system_schema."simulation_profiles"."fw_version" IS 'Phiên bản Firmware của thiết bị DUT cần test (hỗ trợ tự động phân giải field data)';
COMMENT ON COLUMN system_schema."simulation_profiles"."auto_check_criteria" IS 'Bộ tiêu chí kiểm tra tự động hợp nhất với Simulation Flow (Measurement Window, Average, Check Value, ...)';
COMMENT ON COLUMN system_schema."simulation_profiles"."reference_devices" IS 'Danh sách cấu hình các thiết bị tham chiếu (multi-reference devices), có thể để trống';
COMMENT ON COLUMN system_schema."simulation_profiles"."simulator_device" IS 'Cấu hình thiết bị mô phỏng nếu có, có thể để trống';

-- 2. Extend device_test_batches for multi-reference and unified profile execution
ALTER TABLE system_schema."device_test_batches"
  ADD COLUMN IF NOT EXISTS "reference_devices" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "simulator_device" JSONB DEFAULT NULL;

CREATE INDEX IF NOT EXISTS "idx_dtest_batches_ref_devices_gin"
  ON system_schema."device_test_batches" USING GIN ("reference_devices");

COMMENT ON COLUMN system_schema."device_test_batches"."reference_devices" IS 'Danh sách các thiết bị tham chiếu áp dụng cho Test Batch';
COMMENT ON COLUMN system_schema."device_test_batches"."simulator_device" IS 'Cấu hình thiết bị mô phỏng cho Test Batch';

-- 3. Extend device_test_batch_items for multi-reference data, measurement window & average metrics
ALTER TABLE system_schema."device_test_batch_items"
  ADD COLUMN IF NOT EXISTS "reference_devices_data" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "window_packet_count" INTEGER,
  ADD COLUMN IF NOT EXISTS "start_counter" BIGINT,
  ADD COLUMN IF NOT EXISTS "end_counter" BIGINT,
  ADD COLUMN IF NOT EXISTS "reference_window_packet_count" INTEGER,
  ADD COLUMN IF NOT EXISTS "avg_metrics" JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN system_schema."device_test_batch_items"."reference_devices_data" IS 'Dữ liệu đo và so sánh chi tiết từ nhiều thiết bị tham chiếu';
COMMENT ON COLUMN system_schema."device_test_batch_items"."window_packet_count" IS 'Số gói tin nhận được trong Measurement Window = End Counter - Start Counter';
COMMENT ON COLUMN system_schema."device_test_batch_items"."start_counter" IS 'Giá trị Counter tại thời điểm bắt đầu Measurement Window';
COMMENT ON COLUMN system_schema."device_test_batch_items"."end_counter" IS 'Giá trị Counter tại thời điểm kết thúc Measurement Window';
COMMENT ON COLUMN system_schema."device_test_batch_items"."reference_window_packet_count" IS 'Số gói tin trong Measurement Window của thiết bị tham chiếu';
COMMENT ON COLUMN system_schema."device_test_batch_items"."avg_metrics" IS 'Kết quả tính toán Average độc lập cho DUT/Reference/Simulator (giá trị, sample count, metric, mode)';

-- Extend device_autocheck_profiles for multi-reference compatibility if table exists
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'system_schema' AND table_name = 'device_autocheck_profiles') THEN
    ALTER TABLE system_schema."device_autocheck_profiles"
      ADD COLUMN IF NOT EXISTS "reference_devices" JSONB DEFAULT '[]'::jsonb;
  END IF;
END $$;

-- 4. Update views

-- 4.1 Update v_simulation_flows view
DROP VIEW IF EXISTS system_schema.v_simulation_flows;
CREATE OR REPLACE VIEW system_schema.v_simulation_flows AS
SELECT
  p.id,
  p.simu_id,
  COALESCE(p.name, p.profile_name, p.simu_id) AS name,
  p.description,
  p.item_code,
  COALESCE(p.fw_version, p.long_fw) AS fw_version,
  p.sku,
  p.long_fw,
  COALESCE(p.sensor_connectivity, 'LoRaWAN') AS sensor_connectivity,
  p.flow_duration_minutes,
  p.flow_blocks,
  jsonb_array_length(CASE WHEN jsonb_typeof(p.flow_blocks) = 'array'
    THEN p.flow_blocks ELSE '[]'::jsonb END) AS block_count,
  p.timed_actions,
  p.auto_check_criteria,
  CASE
    WHEN jsonb_typeof(p.auto_check_criteria->'rules') = 'array'
      THEN jsonb_array_length(p.auto_check_criteria->'rules')
    WHEN jsonb_typeof(p.auto_check_criteria) = 'object' AND p.auto_check_criteria != '{}'::jsonb
      THEN 1
    ELSE 0
  END AS rule_count,
  p.reference_devices,
  p.simulator_device,
  p.created_by,
  p.created_at,
  p.updated_at
FROM system_schema.simulation_profiles p;

-- 4.2 Update v_device_test_batches view
DROP VIEW IF EXISTS system_schema.v_device_test_batches CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_test_batches AS
SELECT
  b."id",
  b."batch_code",
  b."batch_name",
  b."item_code",
  b."long_fw",
  b."fw_version",
  b."simu_id",
  b."simulation_flow",
  b."flow_duration_seconds",
  b."auto_check_criteria",
  b."reference_devices",
  b."simulator_device",
  b."max_devices",
  b."status",
  b."verdict",
  b."duration_seconds",
  b."started_at",
  b."finished_at",
  b."created_by",
  b."created_at",
  b."updated_at",
  COUNT(i."id")::INTEGER AS "total_devices",
  COUNT(CASE WHEN i."status" = 'PASS' THEN 1 END)::INTEGER AS "pass_devices",
  COUNT(CASE WHEN i."status" = 'FAIL' THEN 1 END)::INTEGER AS "fail_devices",
  COUNT(CASE WHEN i."status" = 'RUNNING' THEN 1 END)::INTEGER AS "running_devices"
FROM system_schema."device_test_batches" b
LEFT JOIN system_schema."device_test_batch_items" i
  ON b."id" = i."batch_id"
GROUP BY b."id";

-- 4.3 Update v_device_test_batch_items_detail view
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
  i."reference_devices_data",
  i."window_packet_count",
  i."start_counter",
  i."end_counter",
  i."reference_window_packet_count",
  i."avg_metrics",
  i."logs",
  i."created_at",
  i."updated_at"
FROM system_schema."device_test_batch_items" i
JOIN system_schema."device_test_batches" b
  ON i."batch_id" = b."id";

-- 5. Grant runtime privileges
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_test_batches TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_system_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_test_batches TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_ops_user;
    GRANT SELECT ON system_schema.v_device_test_batches TO itest_ops_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_ops_user;
  END IF;
END $$;
