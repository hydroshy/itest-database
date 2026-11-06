-- ==============================================================================
-- MIGRATION: 011_create_list_device_testing_menu_and_indexes.sql
-- Module: testing / system
-- Schema: system_schema
-- Target: device_test_registrations, menu_items, role_menu_permissions
-- Description:
--   1. Add high-performance indexes on device_test_registrations for (created_by, application_id)
--      and (application_id, created_at DESC) to optimize user and admin queries.
--   2. Register 'List Device Testing' menu item under 'testing' plugin (tab=list-device-testing).
--   3. Register view and delete permissions for List Device Testing.
--   4. Assign menu and action permissions to ADMIN, OPERATOR, TESTER, QA_ENGINEER roles.
--   5. Create dedicated view v_list_device_testing returning the 11 key fields specified by Human:
--      (Serial Number, Item Code, FW Version, HW Version, FW Code, DevEUI, AppEUI, AppKey, Class, Region, Created by).
--   6. Grant runtime permissions to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. High-Performance Query Indexes
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_app_id"
  ON system_schema."device_test_registrations" ("application_id");

CREATE INDEX IF NOT EXISTS "idx_dtest_reg_created_by"
  ON system_schema."device_test_registrations" ("created_by");

CREATE INDEX IF NOT EXISTS "idx_dtest_reg_user_app"
  ON system_schema."device_test_registrations" ("created_by", "application_id", "created_at" DESC);

CREATE INDEX IF NOT EXISTS "idx_dtest_reg_admin_app"
  ON system_schema."device_test_registrations" ("application_id", "created_at" DESC);

-- 2. Register 'List Device Testing' Menu Item
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES (
  'testing:list-device-testing',
  'List Device Testing',
  'Danh sách thiết bị kiểm thử được tạo bởi người dùng trong default application_id',
  '/plugins/testing?tab=list-device-testing',
  'List',
  'plugin',
  'testing',
  'list-device-testing',
  13,
  true
)
ON CONFLICT ("id") DO UPDATE SET
  "title" = EXCLUDED."title",
  "description" = EXCLUDED."description",
  "route" = EXCLUDED."route",
  "icon" = EXCLUDED."icon",
  "category" = EXCLUDED."category",
  "pluginId" = EXCLUDED."pluginId",
  "tab" = EXCLUDED."tab",
  "order" = EXCLUDED."order",
  "isActive" = EXCLUDED."isActive",
  "updated_at" = CURRENT_TIMESTAMP;

-- 3. Register Permissions
INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  ('menu:testing-list-device:view', 'Access List Device Testing tab', 'menu', 'read'),
  ('testing:device:delete', 'Delete test device from ChirpStack and local registration', 'testing', 'delete')
ON CONFLICT ("name") DO UPDATE SET
  "description" = EXCLUDED."description",
  "module" = EXCLUDED."module",
  "action" = EXCLUDED."action";

-- 4. Assign Role Permissions
-- Ensure roleCode allows NULL if legacy constraint exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema'
      AND table_name = 'role_menu_permissions'
      AND column_name = 'roleCode'
      AND is_nullable = 'NO'
  ) THEN
    ALTER TABLE system_schema."role_menu_permissions" ALTER COLUMN "roleCode" DROP NOT NULL;
  END IF;
END $$;

-- ADMIN: Full view and manage/delete
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('ADMIN', 'admin')
  AND m."id" = 'testing:list-device-testing'
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- OPERATOR, TESTER, QA_ENGINEER: View and delete own devices
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('OPERATOR', 'operator', 'TESTER', 'tester', 'QA_ENGINEER', 'qa_engineer', 'TECHNICIAN', 'technician')
  AND m."id" = 'testing:list-device-testing'
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 5. Dedicated Concise View: system_schema.v_list_device_testing
-- Exposes the 11 key fields requested by Human:
-- 1. Serial Number
-- 2. Item Code
-- 3. FW Version
-- 4. HW Version
-- 5. FW Code
-- 6. DevEUI
-- 7. AppEUI
-- 8. AppKey
-- 9. Class (class_mode)
-- 10. Region (region_code)
-- 11. Created by (created_by)
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

-- 6. Runtime Privilege Grants
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_test_registrations" TO itest_system_user;
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_test_registrations" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON TABLE system_schema."device_test_registrations" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_list_device_testing TO itest_ops_user;
  END IF;
END $$;
