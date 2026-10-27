-- ==============================================================================
-- MIGRATION: 006_add_gateway_testing_and_device_plugin_menus.sql
-- Description:
--   1. Separate Device Domain from Testing Plugin:
--      - Alter default plugin_id of system_schema.devices to 'device'
--      - Backfill existing device records with plugin_id = 'testing' to 'device'
--      - If devices.devices exists, update default plugin_id to 'device' as well
--   2. Add dedicated 'Gateway Testing' menu under plugin 'testing':
--      - id: 'testing:gateway', title: 'Gateway Testing', route: '/plugins/testing?tab=gateway', icon: 'Odometer'
--   3. Add dedicated 'Thiết Bị (Devices)' menu under plugin 'device':
--      - id: 'device:devices', title: 'Thiết Bị (Devices)', route: '/plugins/device?tab=devices', icon: 'Cpu'
--   4. Seed permissions into system_schema.permission and role_menu_permissions
--   5. Refresh compatibility views (system_schema.system_menu_items, public.system_menu_items,
--      public.menu_items, system_schema.testing_devices, devices.testing_devices)
--   6. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_admin
-- Schema: system_schema, public, devices
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Insert or Upsert Menu Items for Gateway Testing & Device Management
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES
  ('testing:gateway', 'Gateway Testing', 'Đo kiểm Gateway, kiểm tra RF/RSSI/SNR, gói tin và liên kết ChirpStack', '/plugins/testing?tab=gateway', 'Odometer', 'plugin', 'testing', 'gateway', 11, true),
  ('device:devices', 'Thiết Bị (Devices)', 'Quản lý thông tin thiết bị, serial number, network ID và truy vết nguồn gốc', '/plugins/device?tab=devices', 'Cpu', 'plugin', 'device', 'devices', 12, true)
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

-- 2. Seed Granular Permissions into system_schema.permission
INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  ('menu:testing-gateway:view', 'Access Gateway Testing card', 'menu', 'read'),
  ('menu:device-devices:view', 'Access Device Management card', 'menu', 'read'),
  ('testing:gateway:manage', 'Manage gateway testing flows and sessions', 'testing', 'manage'),
  ('device:devices:manage', 'Manage devices and registrations', 'device', 'manage')
ON CONFLICT ("name") DO UPDATE SET
  "description" = EXCLUDED."description",
  "module" = EXCLUDED."module",
  "action" = EXCLUDED."action";

-- 3. Assign Role Menu Permissions
-- A. SUPER_ADMIN, ADMIN, administrator, admin: Full access to all menus
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUPER_ADMIN', 'ADMIN', 'administrator', 'admin')
  AND m."id" IN ('testing:gateway', 'device:devices')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- B. SUB_ADMIN, sub_admin: Gateway Testing & Devices access
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUB_ADMIN', 'sub_admin')
  AND m."id" IN ('testing:gateway', 'device:devices')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- C. OPERATOR, operator, TESTER, tester: Gateway Testing & Devices access
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('OPERATOR', 'operator', 'TESTER', 'tester')
  AND m."id" IN ('testing:gateway', 'device:devices')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 4. Separate Device Domain: Update default plugin_id and backfill existing records
-- In system_schema.devices
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'devices' AND column_name = 'plugin_id'
  ) THEN
    ALTER TABLE system_schema."devices" ALTER COLUMN "plugin_id" SET DEFAULT 'device';
    UPDATE system_schema."devices"
    SET "plugin_id" = 'device'
    WHERE "plugin_id" = 'testing' OR "plugin_id" IS NULL;
  END IF;
END $$;

-- In devices.devices (if table exists)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'plugin_id'
  ) THEN
    ALTER TABLE devices.devices ALTER COLUMN plugin_id SET DEFAULT 'device';
    UPDATE devices.devices
    SET plugin_id = 'device'
    WHERE plugin_id = 'testing' OR plugin_id IS NULL;
  END IF;
END $$;

-- 5. Refresh Compatibility Views safely
CREATE OR REPLACE VIEW system_schema."system_menu_items" AS
SELECT * FROM system_schema."menu_items";

CREATE OR REPLACE VIEW public."system_menu_items" AS
SELECT * FROM system_schema."menu_items";

CREATE OR REPLACE VIEW public."menu_items" AS
SELECT * FROM system_schema."menu_items";

-- 6. Grant Idempotent Runtime Privileges
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."menu_items" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."role_menu_permissions" TO itest_system_user;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'system_schema' AND table_name = 'devices') THEN
      GRANT ALL PRIVILEGES ON TABLE system_schema."devices" TO itest_system_user;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'system_schema' AND table_name = 'device_packets') THEN
      GRANT ALL PRIVILEGES ON TABLE system_schema."device_packets" TO itest_system_user;
    END IF;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA system_schema TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_plugins_user;
    GRANT SELECT ON TABLE system_schema."menu_items" TO itest_plugins_user;
    GRANT SELECT ON TABLE system_schema."role_menu_permissions" TO itest_plugins_user;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'system_schema' AND table_name = 'devices') THEN
      GRANT ALL PRIVILEGES ON TABLE system_schema."devices" TO itest_plugins_user;
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'system_schema' AND table_name = 'device_packets') THEN
      GRANT ALL PRIVILEGES ON TABLE system_schema."device_packets" TO itest_plugins_user;
    END IF;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_admin') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_admin;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA system_schema TO itest_admin;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA system_schema TO itest_admin;
  END IF;
END $$;
