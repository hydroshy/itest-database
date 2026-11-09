-- ==============================================================================
-- MIGRATION: 024_create_device_calibration_logs_and_views.sql
-- Module: testing / system / calibration
-- Schema: system_schema
-- Target: device_calibration_logs, device_test_batch_items,
--         v_device_calibration_history, v_device_test_batch_items_detail
-- Description:
--   1. Create device_calibration_logs table:
--      - Support Two-Point (y = a*x + b) & Multi-Point Sensor Calibration.
--      - Track raw values (x1, x2), reference standards (y1, y2), calculated coefficients (a, b).
--      - Track measurement window IDs (window_id_1, window_id_2), execution ID, device identity.
--      - Track LoRaWAN downlink delivery status & verification results.
--   2. Extend device_test_batch_items:
--      - Add calibration_data JSONB column for per-item calibration summary.
--   3. Create view v_device_calibration_history for historical traceability queries.
--   4. Update view v_device_test_batch_items_detail to expose calibration_data.
--   5. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Create device_calibration_logs table
CREATE TABLE IF NOT EXISTS system_schema."device_calibration_logs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "calibration_id" VARCHAR(50) NOT NULL UNIQUE DEFAULT ('CAL-' || upper(replace(gen_random_uuid()::text, '-', ''))),
  "batch_id" UUID REFERENCES system_schema."device_test_batches"("id") ON DELETE CASCADE,
  "batch_item_id" UUID REFERENCES system_schema."device_test_batch_items"("id") ON DELETE CASCADE,
  "execution_id" VARCHAR(100) NOT NULL,
  "simu_id" VARCHAR(100) REFERENCES system_schema."simulation_profiles"("simu_id") ON DELETE SET NULL,
  "device_test_registration_id" UUID REFERENCES system_schema."device_test_registrations"("id") ON DELETE SET NULL,
  "serial_number" VARCHAR(100) NOT NULL,
  "dev_eui" VARCHAR(64) NOT NULL,
  "item_code" VARCHAR(100) NOT NULL,
  "fw_version" VARCHAR(100),
  "calibration_type" VARCHAR(50) NOT NULL DEFAULT 'TWO_POINT',
  "formula" VARCHAR(100) NOT NULL DEFAULT 'y = a*x + b',
  "x1" DOUBLE PRECISION,
  "y1" DOUBLE PRECISION,
  "x2" DOUBLE PRECISION,
  "y2" DOUBLE PRECISION,
  "coeff_a" DOUBLE PRECISION,
  "coeff_b" DOUBLE PRECISION,
  "window_id_1" VARCHAR(100),
  "window_id_2" VARCHAR(100),
  "points_data" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "downlink_status" VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  "downlink_payload" VARCHAR(255),
  "downlink_fport" INTEGER DEFAULT 10,
  "downlink_tx_time" TIMESTAMPTZ,
  "verification_status" VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  "verification_details" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "status" VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  "error_message" TEXT,
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'system',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_calib_logs_batch_id"
  ON system_schema."device_calibration_logs" ("batch_id");

CREATE INDEX IF NOT EXISTS "idx_calib_logs_execution_id"
  ON system_schema."device_calibration_logs" ("execution_id");

CREATE INDEX IF NOT EXISTS "idx_calib_logs_serial"
  ON system_schema."device_calibration_logs" ("serial_number");

CREATE INDEX IF NOT EXISTS "idx_calib_logs_dev_eui"
  ON system_schema."device_calibration_logs" ("dev_eui");

CREATE INDEX IF NOT EXISTS "idx_calib_logs_item_code"
  ON system_schema."device_calibration_logs" ("item_code");

CREATE INDEX IF NOT EXISTS "idx_calib_logs_created_at"
  ON system_schema."device_calibration_logs" ("created_at" DESC);

COMMENT ON TABLE system_schema."device_calibration_logs" IS 'Lịch sử thực thi hiệu chuẩn cảm biến (Two-Point Calibration / Multi-Point) qua Simulation Flow';
COMMENT ON COLUMN system_schema."device_calibration_logs"."calibration_id" IS 'Mã định danh duy nhất của lượt hiệu chuẩn';
COMMENT ON COLUMN system_schema."device_calibration_logs"."execution_id" IS 'ID đợt thực thi Simulation Run / Test Batch tương ứng';
COMMENT ON COLUMN system_schema."device_calibration_logs"."x1" IS 'Giá trị raw trung bình của DUT tại điểm chuẩn 1 (ví dụ 0 ppm)';
COMMENT ON COLUMN system_schema."device_calibration_logs"."y1" IS 'Giá trị chuẩn tại điểm 1 (ví dụ 0 ppm)';
COMMENT ON COLUMN system_schema."device_calibration_logs"."x2" IS 'Giá trị raw trung bình của DUT tại điểm chuẩn 2 (ví dụ 20 ppm)';
COMMENT ON COLUMN system_schema."device_calibration_logs"."y2" IS 'Giá trị chuẩn tại điểm 2 (ví dụ 20 ppm)';
COMMENT ON COLUMN system_schema."device_calibration_logs"."coeff_a" IS 'Hệ số góc (slope) a = (y2 - y1) / (x2 - x1)';
COMMENT ON COLUMN system_schema."device_calibration_logs"."coeff_b" IS 'Hệ số tự do (offset/intercept) b = y1 - a * x1';
COMMENT ON COLUMN system_schema."device_calibration_logs"."window_id_1" IS 'ID Measurement Window tại điểm 1';
COMMENT ON COLUMN system_schema."device_calibration_logs"."window_id_2" IS 'ID Measurement Window tại điểm 2';
COMMENT ON COLUMN system_schema."device_calibration_logs"."downlink_status" IS 'Trạng thái gửi lệnh Downlink nạp hệ số hiệu chuẩn vào DUT';
COMMENT ON COLUMN system_schema."device_calibration_logs"."verification_status" IS 'Kết quả kiểm tra xác minh sau hiệu chuẩn (Device Auto Check)';

-- 2. Extend device_test_batch_items
ALTER TABLE system_schema."device_test_batch_items"
  ADD COLUMN IF NOT EXISTS "calibration_data" JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN system_schema."device_test_batch_items"."calibration_data" IS 'Tóm tắt dữ liệu hiệu chuẩn cảm biến của thiết bị trong đợt test';

-- 3. Create view v_device_calibration_history
DROP VIEW IF EXISTS system_schema.v_device_calibration_history CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_calibration_history AS
SELECT
  c."id",
  c."calibration_id",
  c."batch_id",
  b."batch_code",
  b."batch_name",
  c."batch_item_id",
  c."execution_id",
  c."simu_id",
  p."profile_name" AS "flow_profile_name",
  c."device_test_registration_id",
  c."serial_number",
  c."dev_eui",
  c."item_code",
  c."fw_version",
  c."calibration_type",
  c."formula",
  c."x1",
  c."y1",
  c."x2",
  c."y2",
  c."coeff_a",
  c."coeff_b",
  c."window_id_1",
  c."window_id_2",
  c."points_data",
  c."downlink_status",
  c."downlink_payload",
  c."downlink_fport",
  c."downlink_tx_time",
  c."verification_status",
  c."verification_details",
  c."status",
  c."error_message",
  c."metadata",
  c."created_by",
  c."created_at",
  c."updated_at"
FROM system_schema."device_calibration_logs" c
LEFT JOIN system_schema."device_test_batches" b ON c."batch_id" = b."id"
LEFT JOIN system_schema."simulation_profiles" p ON c."simu_id" = p."simu_id";

-- 4. Update view v_device_test_batch_items_detail to expose calibration_data
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
  i."calibration_data",
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
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema.device_calibration_logs TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_calibration_history TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_system_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema.device_calibration_logs TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_calibration_history TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.device_calibration_logs TO itest_ops_user;
    GRANT SELECT ON system_schema.v_device_calibration_history TO itest_ops_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_ops_user;
  END IF;
END $$;
