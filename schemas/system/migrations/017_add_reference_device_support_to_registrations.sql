-- ==============================================================================
-- MIGRATION: 017_add_reference_device_support_to_registrations.sql
-- Module: testing / system
-- Schema: system_schema
-- Target: device_test_registrations, v_reference_devices, v_list_device_testing
-- Description:
--   1. Idempotently ensure columns long_fw and is_reference exist on device_test_registrations.
--   2. Create view system_schema.v_reference_devices for querying reference devices dynamically without mock data.
--   3. Update view system_schema.v_list_device_testing.
--   4. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Ensure required columns exist on device_test_registrations before defining views
ALTER TABLE system_schema."device_test_registrations"
  ADD COLUMN IF NOT EXISTS "long_fw" VARCHAR(255),
  ADD COLUMN IF NOT EXISTS "is_reference" BOOLEAN NOT NULL DEFAULT false;

-- Backfill long_fw from fw_version if not set
UPDATE system_schema."device_test_registrations"
SET "long_fw" = "fw_version"
WHERE "long_fw" IS NULL AND "fw_version" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "idx_dtest_reg_is_reference"
  ON system_schema."device_test_registrations" ("is_reference");

-- 2. Create view v_reference_devices
CREATE OR REPLACE VIEW system_schema.v_reference_devices AS
SELECT
  r."id",
  r."serial_number",
  r."dev_eui",
  r."item_code",
  r."fw_version",
  COALESCE(r."long_fw", r."fw_version") AS "long_fw",
  r."hw_version",
  COALESCE(r."region_code", 'AS923-1') AS "region_code",
  COALESCE(r."class_mode", 'A') AS "class_mode",
  r."status",
  r."created_by",
  r."created_at",
  r."updated_at"
FROM system_schema."device_test_registrations" r
WHERE r."is_reference" = true
   OR r."status" ILIKE '%reference%'
   OR r."status" ILIKE '%calibrated%'
   OR r."serial_number" ILIKE 'REF-%'
   OR r."serial_number" ILIKE 'STD-%'
   OR r."serial_number" ILIKE 'CAL-%';

COMMENT ON VIEW system_schema.v_reference_devices IS 'Danh sách thiết bị chuẩn (Golden Reference) từ đăng ký thiết bị thực tế';

-- 3. Update view v_list_device_testing to include is_reference at the end
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
  COALESCE(r."is_reference", false) AS "is_reference"
FROM system_schema."device_test_registrations" r
LEFT JOIN lorawan_chirpstack."network_servers" ns
  ON r."network_server_id" = ns."id";

-- 4. Grant runtime privileges
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON system_schema.v_reference_devices TO itest_system_user;
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON system_schema.v_reference_devices TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.v_reference_devices TO itest_ops_user;
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_ops_user;
  END IF;
END $$;
