-- ==============================================================================
-- MIGRATION: 027_add_test_batch_id_and_simulation_vars.sql
-- Description: Add test_batch_id to device_test_registrations, add simulation_vars
--              to device_test_batches and device_test_batch_items, and update
--              v_list_device_testing view to expose test_batch_id.
-- Module: system_schema / testing
-- Schema: system_schema
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Add test_batch_id to device_test_registrations
ALTER TABLE system_schema."device_test_registrations"
  ADD COLUMN IF NOT EXISTS "test_batch_id" UUID;

COMMENT ON COLUMN system_schema."device_test_registrations"."test_batch_id"
  IS 'Khóa ngoại / UUID của Test Batch hiện tại hoặc gần nhất mà thiết bị tham gia kiểm thử';

CREATE INDEX IF NOT EXISTS "idx_dtest_reg_test_batch_id"
  ON system_schema."device_test_registrations" ("test_batch_id");

-- 2. Add simulation_vars to device_test_batches
ALTER TABLE system_schema."device_test_batches"
  ADD COLUMN IF NOT EXISTS "simulation_vars" JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN system_schema."device_test_batches"."simulation_vars"
  IS 'Lưu trữ các biến mô phỏng (tính toán tuyến tính, chuyển đổi hex, giá trị trung bình...) trong suốt quá trình chạy flow';

-- 3. Add simulation_vars to device_test_batch_items
ALTER TABLE system_schema."device_test_batch_items"
  ADD COLUMN IF NOT EXISTS "simulation_vars" JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN system_schema."device_test_batch_items"."simulation_vars"
  IS 'Lưu trữ các biến mô phỏng cụ thể áp dụng hoặc sinh ra cho thiết bị DUT này';

-- 4. Recreate v_list_device_testing view exposing test_batch_id
DROP VIEW IF EXISTS system_schema.v_list_device_testing CASCADE;
CREATE OR REPLACE VIEW system_schema.v_list_device_testing AS
SELECT
  r."id",
  r."registration_code",
  r."serial_number",
  r."item_code",
  r."fw_version",
  COALESCE(r."long_fw", r."fw_version") AS "long_fw",
  r."hw_version",
  r."fw_code",
  r."me_version",
  r."dev_eui",
  r."app_eui",
  r."app_key",
  r."class_mode",
  COALESCE(r."class_mode", 'A') AS "class",
  r."region_code",
  COALESCE(r."region_code", 'AS923-1') AS "region",
  r."sensor_type",
  r."created_by",
  COALESCE(r."application_id", ns."application_id") AS "application_id",
  COALESCE(r."device_profile_id", ns."device_profile_id") AS "device_profile_id",
  r."network_server_id",
  COALESCE(ns."name", r."network_server_name") AS "network_server_name",
  COALESCE(ns."api_url", r."network_server_url") AS "network_server_url",
  r."connectivity",
  r."so_number",
  r."wa_number",
  r."status",
  r."message",
  r."error_detail",
  r."created_at",
  r."updated_at",
  COALESCE(r."is_reference", false) AS "is_reference",
  r."test_batch_id"
FROM system_schema."device_test_registrations" r
LEFT JOIN lorawan_chirpstack."network_servers" ns
  ON (r."network_server_id" = ns."id");

-- 5. Grant permissions
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_system_user;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_ops_user;
  END IF;
END $$;
