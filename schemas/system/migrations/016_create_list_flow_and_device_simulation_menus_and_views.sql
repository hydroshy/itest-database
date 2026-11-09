-- ==============================================================================
-- MIGRATION: 016_create_list_flow_and_device_simulation_menus_and_views.sql
-- Module: testing / system
-- Schema: system_schema
-- Target: simulation_profiles, v_simulation_flows, v_simulation_devices, menu_items, role_menu_permissions
-- Description:
--   1. Decouple Flow Simulation from Device Creation:
--      - Ensure simulation_profiles table exists with all required columns (sku, sensor_connectivity, flow_blocks, name, description, is_flow_template).
--      - Relax device-specific NOT NULL constraints on simulation_profiles (device_name, profile_name).
--   2. Create view system_schema.v_simulation_flows for listing Flow Simulation templates.
--   3. Refresh view system_schema.v_simulation_devices for listing simulation devices.
--   4. Register menu items:
--      - 'testing:list-flow-simulation' (tab=list-flow-simulation)
--      - 'testing:list-device-simulation' (tab=list-device-simulation)
--   5. Grant role menu permissions to ADMIN, OPERATOR, TESTER, QA_ENGINEER, TECHNICIAN.
--   6. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Ensure table simulation_profiles exists
CREATE TABLE IF NOT EXISTS system_schema."simulation_profiles" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "simu_id" VARCHAR(100) NOT NULL UNIQUE,
  "profile_name" VARCHAR(255),
  "name" VARCHAR(255),
  "description" TEXT,
  "serial_number" VARCHAR(100),
  "network_id" VARCHAR(100),
  "device_name" VARCHAR(255),
  "device_type" VARCHAR(100) NOT NULL DEFAULT 'lorawan_node',
  "plugin_id" VARCHAR(100) NOT NULL DEFAULT 'testing',
  "so_number" VARCHAR(100),
  "wa_number" VARCHAR(100),
  "item_code" VARCHAR(100),
  "sku" VARCHAR(100),
  "status" VARCHAR(50) NOT NULL DEFAULT 'template',
  "long_fw" VARCHAR(255),
  "sensor_connectivity" VARCHAR(100) NOT NULL DEFAULT 'LoRaWAN',
  "flow_blocks" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "flow_duration_minutes" INTEGER NOT NULL DEFAULT 30,
  "timed_actions" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "is_flow_template" BOOLEAN NOT NULL DEFAULT TRUE,
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'admin',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Idempotently ensure all columns exist before any view definition
ALTER TABLE system_schema."simulation_profiles"
  ADD COLUMN IF NOT EXISTS "sensor_connectivity" VARCHAR(100) NOT NULL DEFAULT 'LoRaWAN',
  ADD COLUMN IF NOT EXISTS "sku" VARCHAR(100),
  ADD COLUMN IF NOT EXISTS "flow_blocks" JSONB NOT NULL DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS "name" VARCHAR(255),
  ADD COLUMN IF NOT EXISTS "description" TEXT,
  ADD COLUMN IF NOT EXISTS "is_flow_template" BOOLEAN NOT NULL DEFAULT TRUE;

-- Relax constraints if present
DO $$
BEGIN
  ALTER TABLE system_schema."simulation_profiles" ALTER COLUMN "device_name" DROP NOT NULL;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  ALTER TABLE system_schema."simulation_profiles" ALTER COLUMN "profile_name" DROP NOT NULL;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

COMMENT ON COLUMN system_schema."simulation_profiles"."sku" IS 'Mã SKU model sản phẩm';
COMMENT ON COLUMN system_schema."simulation_profiles"."sensor_connectivity" IS 'Loại kết nối cảm biến (LoRaWAN, RS485...)';
COMMENT ON COLUMN system_schema."simulation_profiles"."flow_blocks" IS 'Chuỗi Function Blocks mô phỏng kiểm thử';
COMMENT ON COLUMN system_schema."simulation_profiles"."is_flow_template" IS 'Đánh dấu kịch bản Flow Simulation độc lập (không bắt buộc gắn kèm thiết bị vật lý)';

-- 2. Create view v_simulation_flows
DROP VIEW IF EXISTS system_schema.v_simulation_flows CASCADE;
CREATE OR REPLACE VIEW system_schema.v_simulation_flows AS
SELECT
  p."id",
  p."simu_id",
  COALESCE(p."name", p."profile_name", p."simu_id") AS "name",
  p."description",
  p."item_code",
  p."sku",
  p."long_fw",
  COALESCE(p."sensor_connectivity", 'LoRaWAN') AS "sensor_connectivity",
  p."flow_duration_minutes",
  p."flow_blocks",
  jsonb_array_length(
    CASE
      WHEN jsonb_typeof(p."flow_blocks") = 'array' THEN p."flow_blocks"
      ELSE '[]'::jsonb
    END
  ) AS "block_count",
  p."timed_actions",
  p."created_by",
  p."created_at",
  p."updated_at"
FROM system_schema."simulation_profiles" p;

COMMENT ON VIEW system_schema.v_simulation_flows IS 'View danh sách các kịch bản Flow Simulation kiểm thử độc lập';

-- 3. Refresh view v_simulation_devices with dynamic check for devices schema
DO $$
BEGIN
  EXECUTE 'DROP VIEW IF EXISTS system_schema.v_simulation_devices CASCADE;';
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'devices' AND table_name = 'devices'
  ) THEN
    EXECUTE '
      CREATE OR REPLACE VIEW system_schema.v_simulation_devices AS
      SELECT
        d."id",
        d."serial_number",
        d."network_id",
        d."device_name",
        d."device_type",
        d."plugin_id",
        d."so_number",
        d."wa_number",
        d."item_code",
        d."status",
        d."metadata",
        d."created_at",
        d."updated_at"
      FROM system_schema."devices" d
      WHERE d."status" IN (''simulation'', ''template'')
      UNION ALL
      SELECT
        dev."id",
        dev."serial_number",
        dev."network_id",
        dev."device_name",
        dev."device_type",
        dev."plugin_id",
        dev."so_number",
        dev."wa_number",
        dev."item_code",
        dev."status",
        dev."metadata",
        dev."created_at",
        dev."updated_at"
      FROM devices."devices" dev
      WHERE dev."status" IN (''simulation'', ''template'')
        AND NOT EXISTS (
          SELECT 1 FROM system_schema."devices" sd WHERE sd."serial_number" = dev."serial_number"
        );
    ';
  ELSE
    EXECUTE '
      CREATE OR REPLACE VIEW system_schema.v_simulation_devices AS
      SELECT
        d."id",
        d."serial_number",
        d."network_id",
        d."device_name",
        d."device_type",
        d."plugin_id",
        d."so_number",
        d."wa_number",
        d."item_code",
        d."status",
        d."metadata",
        d."created_at",
        d."updated_at"
      FROM system_schema."devices" d
      WHERE d."status" IN (''simulation'', ''template'');
    ';
  END IF;
END $$;

COMMENT ON VIEW system_schema.v_simulation_devices IS 'View danh sách các thiết bị simulation hoặc template';

-- 4. Register Menu Items: 'List Flow Simulation' & 'List Device Simulation'
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES
(
  'testing:list-flow-simulation',
  'List Flow Simulation',
  'Quản lý danh sách các kịch bản Flow Simulation kiểm thử',
  '/plugins/testing?tab=list-flow-simulation',
  'Workflow',
  'plugin',
  'testing',
  'list-flow-simulation',
  16,
  true
),
(
  'testing:list-device-simulation',
  'List Device Simulation',
  'Quản lý danh sách các thiết bị Simulation độc lập',
  '/plugins/testing?tab=list-device-simulation',
  'Cpu',
  'plugin',
  'testing',
  'list-device-simulation',
  17,
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
  "updatedAt" = CURRENT_TIMESTAMP;

-- 5. Register permissions and assign to roles
INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  ('menu:testing-list-flow-simulation:view', 'View List Flow Simulation tab in testing plugin', 'menu', 'read'),
  ('menu:testing-list-device-simulation:view', 'View List Device Simulation tab in testing plugin', 'menu', 'read'),
  ('testing:flow:manage', 'Create, update, delete flow simulation profiles', 'testing', 'manage'),
  ('testing:simulation-device:manage', 'Manage simulation devices', 'testing', 'manage')
ON CONFLICT ("name") DO UPDATE SET
  "description" = EXCLUDED."description",
  "module" = EXCLUDED."module",
  "action" = EXCLUDED."action";

-- Assign menu permissions to all active roles
INSERT INTO system_schema."role_menu_permissions" ("roleId", "menuItemId")
SELECT r."id", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('ADMIN', 'admin', 'OPERATOR', 'operator', 'TESTER', 'tester', 'QA_ENGINEER', 'qa_engineer', 'TECHNICIAN', 'technician')
  AND m."id" IN ('testing:list-flow-simulation', 'testing:list-device-simulation')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- Assign action permissions to roles
INSERT INTO system_schema."role_permissions" ("role_id", "permission_id")
SELECT r."id", p."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."permission" p
WHERE r."code" IN ('ADMIN', 'admin', 'OPERATOR', 'operator', 'TESTER', 'tester', 'QA_ENGINEER', 'qa_engineer')
  AND p."name" IN ('menu:testing-list-flow-simulation:view', 'menu:testing-list-device-simulation:view', 'testing:flow:manage', 'testing:simulation-device:manage')
ON CONFLICT ("role_id", "permission_id") DO NOTHING;

-- 6. Grant runtime privileges
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."simulation_profiles" TO itest_system_user;
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_system_user;
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."simulation_profiles" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema."simulation_profiles" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_ops_user;
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_ops_user;
  END IF;
END $$;
