-- ==============================================================================
-- MIGRATION: 013_add_long_fw_to_device_test_registrations.sql
-- Module: testing / system
-- Schema: system_schema
-- Target: device_test_registrations, v_list_device_testing
-- Description:
--   1. Add long_fw column to device_test_registrations.
--   2. Backfill existing long_fw values from fw_version.
--   3. Update v_list_device_testing view with COALESCE(r."long_fw", r."fw_version") AS "long_fw".
--   4. Grant runtime privileges on updated view to system, plugins, ops users.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Add column to device_test_registrations
ALTER TABLE system_schema."device_test_registrations"
  ADD COLUMN IF NOT EXISTS "long_fw" VARCHAR(255);

-- 2. Backfill long_fw from fw_version
UPDATE system_schema."device_test_registrations"
SET "long_fw" = "fw_version"
WHERE "long_fw" IS NULL AND "fw_version" IS NOT NULL;

-- 3. Update view v_list_device_testing
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
  r."updated_at"
FROM system_schema."device_test_registrations" r
LEFT JOIN lorawan_chirpstack."network_servers" ns
  ON (r."network_server_id" = ns."id");

-- 4. Grant runtime privileges
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."device_test_registrations" TO itest_system_user;
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."device_test_registrations" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema."device_test_registrations" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_ops_user;
  END IF;
END $$;
