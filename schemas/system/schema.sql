-- ==============================================================================
-- ITEST-SYSTEM - CORE MICRO-KERNEL SCHEMA (POSTGRESQL 17)
-- ==============================================================================
-- File: schemas/system/schema.sql
-- Description: Core schema containing Identity/RBAC, Plugin Sandboxes, Audit Logs,
--              and Unified Core Device Registry for Micro-kernel Architecture.
-- Schema: system_schema
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Permissions Table
CREATE TABLE IF NOT EXISTS system_schema."permission" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "name" VARCHAR(255) UNIQUE NOT NULL,
  "description" VARCHAR(255),
  "module" VARCHAR(100) NOT NULL DEFAULT 'system',
  "action" VARCHAR(100) NOT NULL DEFAULT 'read',
  "createdAt" TIMESTAMP NOT NULL DEFAULT now()
);

-- 2. Roles Table
CREATE TABLE IF NOT EXISTS system_schema."roles" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "code" VARCHAR(100) UNIQUE NOT NULL,
  "name" VARCHAR(255) NOT NULL,
  "description" VARCHAR(255),
  "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
);

-- 3. Role-Permissions Join Table
CREATE TABLE IF NOT EXISTS system_schema."role_permissions" (
  "role_id" UUID NOT NULL REFERENCES system_schema."roles"("id") ON DELETE CASCADE,
  "permission_id" UUID NOT NULL REFERENCES system_schema."permission"("id") ON DELETE CASCADE,
  CONSTRAINT "PK_role_permissions" PRIMARY KEY ("role_id", "permission_id")
);

-- 4. Users Table
CREATE TABLE IF NOT EXISTS system_schema."users" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "username" VARCHAR(255) UNIQUE NOT NULL,
  "passwordHash" VARCHAR(255) NOT NULL,
  "email" VARCHAR(255),
  "fullName" VARCHAR(255),
  "userType" VARCHAR(50) NOT NULL DEFAULT 'USER',
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "createdById" UUID,
  "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
);

-- 5. User-Role Join Table
CREATE TABLE IF NOT EXISTS system_schema."user_role" (
  "user_id" UUID NOT NULL REFERENCES system_schema."users"("id") ON DELETE CASCADE,
  "role_id" UUID NOT NULL REFERENCES system_schema."roles"("id") ON DELETE CASCADE,
  CONSTRAINT "PK_user_role" PRIMARY KEY ("user_id", "role_id")
);

-- 6. Core Dynamic Plugin Registry
CREATE TABLE IF NOT EXISTS system_schema."core_plugins" (
  "id" VARCHAR(128) PRIMARY KEY,
  "name" VARCHAR(255) NOT NULL,
  "version" VARCHAR(64) NOT NULL,
  "type" VARCHAR(64) NOT NULL DEFAULT 'SYSTEM',
  "schemaName" VARCHAR(128) NOT NULL DEFAULT 'public',
  "status" VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
  "description" TEXT,
  "author" VARCHAR(128),
  "license" VARCHAR(64),
  "repositoryUrl" VARCHAR(512),
  "bundleUrl" VARCHAR(512),
  "bundleType" VARCHAR(32) DEFAULT 'ESM',
  "manifest" JSONB DEFAULT '{}',
  "uiEntry" JSONB,
  "backendEntry" JSONB,
  "permissions" JSONB DEFAULT '[]',
  "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT now()
);

-- 7. Plugin Security and Operation Audit Logs
CREATE TABLE IF NOT EXISTS system_schema."plugin_audit_logs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "pluginId" VARCHAR(128) NOT NULL,
  "version" VARCHAR(64) NOT NULL DEFAULT '1.0.0',
  "action" VARCHAR(32) NOT NULL,
  "operator" VARCHAR(128) NOT NULL DEFAULT 'system',
  "details" JSONB DEFAULT '{}',
  "createdAt" TIMESTAMP NOT NULL DEFAULT now()
);

-- 8. Unified Core Device Registry
CREATE TABLE IF NOT EXISTS system_schema."unified_devices" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "device_id" VARCHAR(100) UNIQUE NOT NULL,
  "name" VARCHAR(255) NOT NULL,
  "type" VARCHAR(100) NOT NULL,
  "protocol" VARCHAR(50) NOT NULL,
  "status" VARCHAR(50) NOT NULL DEFAULT 'offline',
  "metadata" JSONB DEFAULT '{}',
  "created_at" TIMESTAMP NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMP NOT NULL DEFAULT now()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS "idx_users_username" ON system_schema."users"("username");
CREATE INDEX IF NOT EXISTS "idx_roles_code" ON system_schema."roles"("code");
CREATE INDEX IF NOT EXISTS "idx_permission_name" ON system_schema."permission"("name");
CREATE INDEX IF NOT EXISTS "idx_core_plugins_type" ON system_schema."core_plugins"("type");
CREATE INDEX IF NOT EXISTS "idx_core_plugins_status" ON system_schema."core_plugins"("status");
CREATE INDEX IF NOT EXISTS "idx_plugin_audit_plugin_id" ON system_schema."plugin_audit_logs"("pluginId");
CREATE INDEX IF NOT EXISTS "idx_plugin_audit_action" ON system_schema."plugin_audit_logs"("action");
CREATE INDEX IF NOT EXISTS "idx_unified_devices_device_id" ON system_schema."unified_devices"("device_id");
CREATE INDEX IF NOT EXISTS "idx_unified_devices_protocol" ON system_schema."unified_devices"("protocol");

-- Initial Core Seed Data
INSERT INTO system_schema."roles" ("code", "name", "description")
VALUES
  ('admin', 'Admin', 'Full administrative access to micro-kernel core'),
  ('sub_admin', 'Sub-Admin', 'Delegated administrative privileges'),
  ('operator', 'Operator', 'Operational, testing and device execution access')
ON CONFLICT ("code") DO UPDATE SET
  "name" = EXCLUDED."name",
  "description" = EXCLUDED."description";

INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  ('system:users:read', 'View users', 'system', 'read'),
  ('system:users:write', 'Manage users', 'system', 'write'),
  ('system:plugins:manage', 'Install, enable and configure plugins', 'system', 'manage'),
  ('system:devices:read', 'View registered devices', 'system', 'read'),
  ('system:devices:write', 'Register and edit devices', 'system', 'write')
ON CONFLICT ("name") DO NOTHING;

-- Grant permissions to Admin role
INSERT INTO system_schema."role_permissions" ("role_id", "permission_id")
SELECT r."id", p."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."permission" p
WHERE r."code" = 'admin'
ON CONFLICT DO NOTHING;

-- Grant operational permissions to Operator role
INSERT INTO system_schema."role_permissions" ("role_id", "permission_id")
SELECT r."id", p."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."permission" p
WHERE r."code" = 'operator' AND p."name" IN ('system:devices:read', 'system:devices:write')
ON CONFLICT DO NOTHING;

-- Seed Default Admin Account: admin / abc@123 (bcrypt hash)
INSERT INTO system_schema."users" ("username", "passwordHash", "email", "fullName", "userType", "isActive")
VALUES (
  'admin',
  '$2b$10$S3YCsMDJT1NsTLaqmQEgDeNWuQaYSowIriOEsWyO9KohVzf7V3Yha',
  'admin@itest.local',
  'System Administrator',
  'ADMIN',
  true
)
ON CONFLICT ("username") DO UPDATE SET
  "passwordHash" = EXCLUDED."passwordHash",
  "userType" = 'ADMIN',
  "isActive" = true;

-- Link Default Admin to Admin role
INSERT INTO system_schema."user_role" ("user_id", "role_id")
SELECT u."id", r."id"
FROM system_schema."users" u
JOIN system_schema."roles" r ON r."code" = 'admin'
WHERE u."username" = 'admin'
ON CONFLICT DO NOTHING;

-- ==============================================================================
-- MENU ITEMS & ROLE MENU PERMISSIONS
-- ==============================================================================

-- 1. Ensure Standard Roles exist in system_schema.roles
INSERT INTO system_schema."roles" ("code", "name", "description")
VALUES
  ('SUPER_ADMIN', 'Super Admin', 'Full administrative access to all system features and plugins'),
  ('SUB_ADMIN', 'Sub-Admin', 'Delegated administrative privileges'),
  ('OPERATOR', 'Operator', 'Operational, testing and device execution access'),
  ('END_USER', 'End User', 'Standard end user with access to assigned tools')
ON CONFLICT ("code") DO UPDATE SET
  "name" = EXCLUDED."name",
  "description" = EXCLUDED."description";

-- 2. Create menu_items Table
CREATE TABLE IF NOT EXISTS system_schema."menu_items" (
  "id" VARCHAR(128) PRIMARY KEY,
  "title" VARCHAR(255) NOT NULL,
  "description" TEXT,
  "route" VARCHAR(512) NOT NULL,
  "icon" VARCHAR(128) DEFAULT 'Menu',
  "category" VARCHAR(64) NOT NULL DEFAULT 'plugin',
  "pluginId" VARCHAR(128),
  "plugin_id" VARCHAR(128),
  "tab" VARCHAR(64),
  "order" INT NOT NULL DEFAULT 0,
  "display_order" INT NOT NULL DEFAULT 0,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "metadata" JSONB DEFAULT '{}'::jsonb,
  "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
  "created_at" TIMESTAMP NOT NULL DEFAULT now(),
  "updatedAt" TIMESTAMP NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMP NOT NULL DEFAULT now()
);

-- Trigger function to keep camelCase and snake_case columns in sync
CREATE OR REPLACE FUNCTION system_schema.sync_menu_items_columns()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW."pluginId" IS NOT NULL AND NEW."plugin_id" IS NULL THEN
    NEW."plugin_id" := NEW."pluginId";
  ELSIF NEW."plugin_id" IS NOT NULL AND NEW."pluginId" IS NULL THEN
    NEW."pluginId" := NEW."plugin_id";
  END IF;

  IF NEW."order" IS NOT NULL AND (NEW."display_order" IS NULL OR NEW."display_order" = 0) THEN
    NEW."display_order" := NEW."order";
  ELSIF NEW."display_order" IS NOT NULL AND (NEW."order" IS NULL OR NEW."order" = 0) THEN
    NEW."order" := NEW."display_order";
  END IF;

  IF NEW."isActive" IS NOT NULL THEN
    NEW."is_active" := NEW."isActive";
  ELSIF NEW."is_active" IS NOT NULL THEN
    NEW."isActive" := NEW."is_active";
  END IF;

  NEW."updatedAt" := now();
  NEW."updated_at" := now();
  IF NEW."createdAt" IS NULL THEN
    NEW."createdAt" := COALESCE(NEW."created_at", now());
  END IF;
  NEW."created_at" := NEW."createdAt";

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_menu_items_columns ON system_schema."menu_items";
CREATE TRIGGER trg_sync_menu_items_columns
BEFORE INSERT OR UPDATE ON system_schema."menu_items"
FOR EACH ROW
EXECUTE FUNCTION system_schema.sync_menu_items_columns();

CREATE INDEX IF NOT EXISTS "idx_menu_items_category" ON system_schema."menu_items"("category");
CREATE INDEX IF NOT EXISTS "idx_menu_items_plugin_id" ON system_schema."menu_items"("plugin_id");
CREATE INDEX IF NOT EXISTS "idx_menu_items_order" ON system_schema."menu_items"("order");

-- 3. Create role_menu_permissions Table
CREATE TABLE IF NOT EXISTS system_schema."role_menu_permissions" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "roleId" UUID REFERENCES system_schema."roles"("id") ON DELETE CASCADE,
  "role_id" UUID,
  "roleCode" VARCHAR(100),
  "role_code" VARCHAR(100),
  "menuItemId" VARCHAR(128) NOT NULL REFERENCES system_schema."menu_items"("id") ON DELETE CASCADE,
  "menu_item_id" VARCHAR(128),
  "createdAt" TIMESTAMP NOT NULL DEFAULT now(),
  "created_at" TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT "UQ_role_menu_permissions" UNIQUE ("roleId", "menuItemId")
);

-- Trigger function to keep role_menu_permissions columns in sync
CREATE OR REPLACE FUNCTION system_schema.sync_role_menu_permissions_columns()
RETURNS TRIGGER AS $$
DECLARE
  v_role_id UUID;
  v_role_code VARCHAR(100);
BEGIN
  -- Sync roleCode <-> role_code
  IF NEW."roleCode" IS NOT NULL AND NEW."role_code" IS NULL THEN
    NEW."role_code" := NEW."roleCode";
  ELSIF NEW."role_code" IS NOT NULL AND NEW."roleCode" IS NULL THEN
    NEW."roleCode" := NEW."role_code";
  END IF;

  -- Auto-lookup roleId if only role_code / roleCode provided
  IF NEW."roleId" IS NULL AND (NEW."role_code" IS NOT NULL OR NEW."roleCode" IS NOT NULL) THEN
    SELECT id INTO v_role_id FROM system_schema."roles"
    WHERE UPPER("code") = UPPER(COALESCE(NEW."role_code", NEW."roleCode"))
    LIMIT 1;

    IF v_role_id IS NOT NULL THEN
      NEW."roleId" := v_role_id;
      NEW."role_id" := v_role_id;
    END IF;
  ELSIF NEW."roleId" IS NOT NULL AND NEW."role_id" IS NULL THEN
    NEW."role_id" := NEW."roleId";
  ELSIF NEW."role_id" IS NOT NULL AND NEW."roleId" IS NULL THEN
    NEW."roleId" := NEW."role_id";
  END IF;

  -- Auto-lookup roleCode if only roleId / role_id provided
  IF (NEW."roleCode" IS NULL AND NEW."role_code" IS NULL) AND (NEW."roleId" IS NOT NULL OR NEW."role_id" IS NOT NULL) THEN
    SELECT "code" INTO v_role_code FROM system_schema."roles"
    WHERE "id" = COALESCE(NEW."roleId", NEW."role_id")
    LIMIT 1;

    IF v_role_code IS NOT NULL THEN
      NEW."roleCode" := v_role_code;
      NEW."role_code" := v_role_code;
    END IF;
  END IF;

  -- Sync menuItemId <-> menu_item_id
  IF NEW."menuItemId" IS NOT NULL AND NEW."menu_item_id" IS NULL THEN
    NEW."menu_item_id" := NEW."menuItemId";
  ELSIF NEW."menu_item_id" IS NOT NULL AND NEW."menuItemId" IS NULL THEN
    NEW."menuItemId" := NEW."menu_item_id";
  END IF;

  NEW."created_at" := COALESCE(NEW."createdAt", NEW."created_at", now());
  NEW."createdAt" := NEW."created_at";

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Backward compatibility alias
CREATE OR REPLACE FUNCTION system_schema.sync_role_menu_permissions()
RETURNS TRIGGER AS $$
BEGIN
  RETURN system_schema.sync_role_menu_permissions_columns();
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_role_menu_permissions ON system_schema."role_menu_permissions";
CREATE TRIGGER trg_sync_role_menu_permissions
BEFORE INSERT OR UPDATE ON system_schema."role_menu_permissions"
FOR EACH ROW
EXECUTE FUNCTION system_schema.sync_role_menu_permissions_columns();

CREATE INDEX IF NOT EXISTS "idx_role_menu_role_id" ON system_schema."role_menu_permissions"("roleId");
CREATE INDEX IF NOT EXISTS "idx_role_menu_role_code" ON system_schema."role_menu_permissions"("roleCode");
CREATE INDEX IF NOT EXISTS "idx_role_menu_menu_item_id" ON system_schema."role_menu_permissions"("menuItemId");

-- 4. Seed Granular Features / Tabs into menu_items
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES
  ('dashboard', 'Dashboard', 'Bảng điều khiển trung tâm và quản trị hệ thống', '/dashboard', 'DataBoard', 'system', NULL, NULL, 1, true),
  ('final-config:tool', 'Final Config Tool', 'Nạp cấu hình thiết bị tự động qua Web Serial và kiểm thử 4 công đoạn', '/plugins/final-config?tab=tool', 'Cpu', 'plugin', 'final-config', 'tool', 2, true),
  ('final-config:manager', 'Final Config Manager', 'Quản lý, tìm kiếm và tra cứu danh sách profile Final Config', '/plugins/final-config?tab=manager', 'Document', 'plugin', 'final-config', 'manager', 3, true),
  ('final-config:create', 'Tạo Final Config', 'Tạo mới cấu hình thiết bị từ Memmap Payload template', '/plugins/final-config?tab=create', 'CirclePlus', 'plugin', 'final-config', 'create', 4, true),
  ('device-traceability:so', 'Sales Orders & Work Authorizations', 'Quản lý cây đơn hàng SO, chỉ thị xuất kho WA và danh sách thiết bị', '/plugins/device-traceability?tab=so', 'List', 'plugin', 'device-traceability', 'so', 5, true),
  ('device-traceability:devices', 'Device Traceability List', 'Tra cứu dòng đời thiết bị, lịch sử test và trạng thái final config', '/plugins/device-traceability?tab=devices', 'Odometer', 'plugin', 'device-traceability', 'devices', 6, true),
  ('device-traceability:config', 'Tra Cứu Cấu Hình Cuối', 'Tra cứu và giám sát cấu hình cuối cùng của thiết bị', '/plugins/device-traceability?tab=config', 'DocumentChecked', 'plugin', 'device-traceability', 'config', 7, true),
  ('memmap-payload:manager', 'Memmap Profiles', 'Quản lý template thanh ghi Modbus định hình payload thiết bị', '/plugins/memmap-payload', 'Collection', 'plugin', 'memmap-payload', 'manager', 8, true),
  ('lorawan-chirpstack:integration', 'LoRaWAN ChirpStack Integration', 'Đồng bộ thiết bị và cấu hình kết nối ChirpStack v4', '/plugins/lorawan-chirpstack', 'Connection', 'plugin', 'lorawan-chirpstack', 'integration', 9, true),
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
  "isActive" = EXCLUDED."isActive";

-- 5. Seed Default Role Menu Permissions Matrix
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUPER_ADMIN', 'admin')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUB_ADMIN', 'sub_admin')
  AND m."id" IN ('dashboard', 'final-config:tool', 'final-config:manager', 'device-traceability:so', 'device-traceability:devices', 'device-traceability:config', 'memmap-payload:manager', 'testing:gateway', 'device:devices')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('OPERATOR', 'operator')
  AND m."id" IN ('final-config:tool', 'device-traceability:devices', 'lorawan-chirpstack:integration', 'testing:gateway', 'device:devices')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('END_USER', 'user')
  AND m."id" IN ('final-config:tool')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 6. Compatibility Views for cross-schema access (public <-> system_schema)
DROP VIEW IF EXISTS system_schema."system_menu_items" CASCADE;
CREATE OR REPLACE VIEW system_schema."system_menu_items" AS
SELECT * FROM system_schema."menu_items";

DROP VIEW IF EXISTS public."system_menu_items" CASCADE;
CREATE OR REPLACE VIEW public."system_menu_items" AS
SELECT * FROM system_schema."menu_items";

DROP VIEW IF EXISTS public."menu_items" CASCADE;
CREATE OR REPLACE VIEW public."menu_items" AS
SELECT * FROM system_schema."menu_items";

DROP VIEW IF EXISTS public."role_menu_permissions" CASCADE;
CREATE OR REPLACE VIEW public."role_menu_permissions" AS
SELECT * FROM system_schema."role_menu_permissions";

-- 7. Devices & Device Packets for Testing & Device Management
CREATE TABLE IF NOT EXISTS system_schema."devices" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "serial_number" VARCHAR(100) NOT NULL UNIQUE,
  "network_id" VARCHAR(100),
  "device_name" VARCHAR(255) NOT NULL,
  "device_type" VARCHAR(100) NOT NULL DEFAULT 'end_device',
  "plugin_id" VARCHAR(128) NOT NULL DEFAULT 'device',
  "so_id" UUID,
  "so_number" VARCHAR(100),
  "wa_id" UUID,
  "wa_number" VARCHAR(100),
  "item_code" VARCHAR(100),
  "status" VARCHAR(50) NOT NULL DEFAULT 'active',
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_devices_serial_number" ON system_schema."devices"("serial_number");
CREATE INDEX IF NOT EXISTS "idx_devices_network_id" ON system_schema."devices"("network_id");
CREATE INDEX IF NOT EXISTS "idx_devices_plugin_id" ON system_schema."devices"("plugin_id");
CREATE INDEX IF NOT EXISTS "idx_devices_so_number" ON system_schema."devices"("so_number");
CREATE INDEX IF NOT EXISTS "idx_devices_wa_number" ON system_schema."devices"("wa_number");
CREATE INDEX IF NOT EXISTS "idx_devices_item_code" ON system_schema."devices"("item_code");
CREATE INDEX IF NOT EXISTS "idx_devices_status" ON system_schema."devices"("status");
CREATE INDEX IF NOT EXISTS "idx_devices_so_id" ON system_schema."devices"("so_id");
CREATE INDEX IF NOT EXISTS "idx_devices_wa_id" ON system_schema."devices"("wa_id");
CREATE INDEX IF NOT EXISTS "idx_devices_metadata_gin" ON system_schema."devices" USING GIN ("metadata");

CREATE TABLE IF NOT EXISTS system_schema."device_packets" (
  "id" BIGSERIAL PRIMARY KEY,
  "device_id" UUID REFERENCES system_schema."devices"("id") ON DELETE CASCADE,
  "dev_eui" VARCHAR(64),
  "packet_type" VARCHAR(50) NOT NULL DEFAULT 'uplink',
  "f_port" INTEGER,
  "f_cnt" BIGINT,
  "rssi" DOUBLE PRECISION,
  "snr" DOUBLE PRECISION,
  "sf" VARCHAR(20),
  "frequency" DOUBLE PRECISION,
  "raw_payload" TEXT,
  "decoded_payload" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "rf_info" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Ensure enhanced telemetry columns exist if table was previously created without them
ALTER TABLE system_schema."device_packets"
  ALTER COLUMN "device_id" DROP NOT NULL;

ALTER TABLE system_schema."device_packets"
  ADD COLUMN IF NOT EXISTS "dev_eui" VARCHAR(64),
  ADD COLUMN IF NOT EXISTS "rssi" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "snr" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "sf" VARCHAR(20),
  ADD COLUMN IF NOT EXISTS "frequency" DOUBLE PRECISION;

CREATE INDEX IF NOT EXISTS "idx_device_packets_dev_eui" ON system_schema."device_packets"("dev_eui");
CREATE INDEX IF NOT EXISTS "idx_device_packets_created_desc" ON system_schema."device_packets"("created_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_device_packets_deveui_created" ON system_schema."device_packets"("dev_eui", "created_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_device_packets_device_id_created_at" ON system_schema."device_packets"("device_id", "created_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_device_packets_packet_type" ON system_schema."device_packets"("packet_type");
CREATE INDEX IF NOT EXISTS "idx_device_packets_decoded_payload_gin" ON system_schema."device_packets" USING GIN ("decoded_payload");
CREATE INDEX IF NOT EXISTS "idx_device_packets_rf_info_gin" ON system_schema."device_packets" USING GIN ("rf_info");

DROP VIEW IF EXISTS system_schema.v_devices_traceability CASCADE;
CREATE OR REPLACE VIEW system_schema.v_devices_traceability AS
SELECT
  d."id" AS "device_id",
  d."serial_number",
  d."network_id",
  d."device_name",
  d."device_type",
  d."plugin_id",
  d."status",
  d."so_id",
  d."so_number",
  d."wa_id",
  d."wa_number",
  d."item_code",
  d."metadata",
  d."created_at",
  d."updated_at",
  so."customer_name",
  so."partner_email",
  wa."planned_quantity" AS "wa_planned_quantity"
FROM system_schema."devices" d
LEFT JOIN traceability_manager."traceability_so" so ON d."so_id" = so."id" OR d."so_number" = so."so_number"
LEFT JOIN traceability_manager."traceability_wa" wa ON d."wa_id" = wa."id" OR d."wa_number" = wa."wa_number";

-- 12. Simulation Profiles Table
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
  "item_code" VARCHAR(100) NOT NULL,
  "sku" VARCHAR(100),
  "sensor_connectivity" VARCHAR(100) NOT NULL DEFAULT 'LoRaWAN',
  "status" VARCHAR(50) NOT NULL DEFAULT 'template',
  "long_fw" VARCHAR(255) NOT NULL,
  "target_device_name" VARCHAR(255),
  "activation" VARCHAR(20) NOT NULL DEFAULT 'OTAA',
  "dev_eui" VARCHAR(64),
  "app_eui" VARCHAR(64) DEFAULT '0000000000000000',
  "app_key" VARCHAR(64),
  "dev_addr" VARCHAR(64),
  "region" VARCHAR(50) NOT NULL DEFAULT 'AS923-1',
  "sf" VARCHAR(20) NOT NULL DEFAULT 'SF7',
  "bw" INTEGER NOT NULL DEFAULT 125,
  "f_port" INTEGER NOT NULL DEFAULT 10,
  "preset_id" VARCHAR(50) NOT NULL DEFAULT 'env',
  "flow_duration_minutes" NUMERIC NOT NULL DEFAULT 30,
  "auto_terminate" BOOLEAN NOT NULL DEFAULT TRUE,
  "uplink_interval_sec" INTEGER NOT NULL DEFAULT 10,
  "timed_actions" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "flow_blocks" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "is_flow_template" BOOLEAN NOT NULL DEFAULT TRUE,
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'admin',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE system_schema."simulation_profiles"
  ADD COLUMN IF NOT EXISTS "sku" VARCHAR(100),
  ADD COLUMN IF NOT EXISTS "flow_blocks" JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS "idx_simu_profiles_simu_id" ON system_schema."simulation_profiles"("simu_id");
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_item_code" ON system_schema."simulation_profiles"("item_code");
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_sku_long_fw" ON system_schema."simulation_profiles"("sku", "long_fw");
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_long_fw" ON system_schema."simulation_profiles"("long_fw");
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_timed_actions_gin" ON system_schema."simulation_profiles" USING GIN ("timed_actions");
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_flow_blocks_gin" ON system_schema."simulation_profiles" USING GIN ("flow_blocks");

-- 13. Simulation Runs Table
CREATE TABLE IF NOT EXISTS system_schema."simulation_runs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "simu_id" VARCHAR(100) NOT NULL REFERENCES system_schema."simulation_profiles"("simu_id") ON DELETE CASCADE,
  "device_id" UUID REFERENCES system_schema."devices"("id") ON DELETE SET NULL,
  "item_code" VARCHAR(100) NOT NULL,
  "long_fw" VARCHAR(255) NOT NULL,
  "status" VARCHAR(50) NOT NULL DEFAULT 'running',
  "duration_seconds" INTEGER NOT NULL DEFAULT 1800,
  "elapsed_seconds" INTEGER NOT NULL DEFAULT 0,
  "speed_multiplier" INTEGER NOT NULL DEFAULT 1,
  "total_uplinks" INTEGER NOT NULL DEFAULT 0,
  "total_downlinks" INTEGER NOT NULL DEFAULT 0,
  "actuator_events" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "logs" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "started_by" VARCHAR(100) NOT NULL DEFAULT 'sub_admin',
  "started_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "finished_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_simu_runs_simu_id" ON system_schema."simulation_runs"("simu_id");
CREATE INDEX IF NOT EXISTS "idx_simu_runs_item_code" ON system_schema."simulation_runs"("item_code");
CREATE INDEX IF NOT EXISTS "idx_simu_runs_status" ON system_schema."simulation_runs"("status");
CREATE INDEX IF NOT EXISTS "idx_simu_runs_started_at" ON system_schema."simulation_runs"("started_at" DESC);

-- 14. Device Test Sessions Table (Create Device Testing in Testing Plugin)
CREATE TABLE IF NOT EXISTS system_schema."device_test_sessions" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "session_code" VARCHAR(100) NOT NULL UNIQUE,
  "device_id" UUID,
  "serial_number" VARCHAR(100),
  "dev_eui" VARCHAR(64),
  "device_name" VARCHAR(255),
  "item_code" VARCHAR(100),
  "sku" VARCHAR(100),
  "connectivity" VARCHAR(50) NOT NULL DEFAULT 'LoRaWAN',
  "simu_id" VARCHAR(100),
  "flow_config" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "auto_check_criteria" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "evaluation_result" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "status" VARCHAR(50) NOT NULL DEFAULT 'IDLE',
  "verdict" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  "packets_received" INTEGER NOT NULL DEFAULT 0,
  "rules_passed" INTEGER NOT NULL DEFAULT 0,
  "rules_failed" INTEGER NOT NULL DEFAULT 0,
  "duration_seconds" INTEGER NOT NULL DEFAULT 0,
  "logs" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "tested_by" VARCHAR(100) NOT NULL DEFAULT 'operator',
  "started_at" TIMESTAMPTZ,
  "finished_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_serial_number" ON system_schema."device_test_sessions"("serial_number");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_dev_eui" ON system_schema."device_test_sessions"("dev_eui");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_item_code" ON system_schema."device_test_sessions"("item_code");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_sku" ON system_schema."device_test_sessions"("sku");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_simu_id" ON system_schema."device_test_sessions"("simu_id");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_status" ON system_schema."device_test_sessions"("status");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_verdict" ON system_schema."device_test_sessions"("verdict");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_started_at" ON system_schema."device_test_sessions"("started_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_created_at" ON system_schema."device_test_sessions"("created_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_flow_config_gin" ON system_schema."device_test_sessions" USING GIN ("flow_config");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_auto_check_gin" ON system_schema."device_test_sessions" USING GIN ("auto_check_criteria");

DROP VIEW IF EXISTS system_schema.v_device_test_sessions CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_test_sessions AS
SELECT * FROM system_schema."device_test_sessions";

-- 15. Device Test Registrations Table (3-Step Registration Flow: LoRaWAN SO/WA -> Serial Fast Read 0..259 -> ChirpStack Provisioning)
CREATE TABLE IF NOT EXISTS system_schema."device_test_registrations" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "registration_code" VARCHAR(100) NOT NULL UNIQUE,
  "connectivity" VARCHAR(50) NOT NULL DEFAULT 'LoRaWAN',
  "so_id" UUID,
  "so_number" VARCHAR(100),
  "wa_id" UUID,
  "wa_number" VARCHAR(100),
  "item_code" VARCHAR(100),
  "network_server_id" UUID,
  "network_server_name" VARCHAR(100),
  "network_server_url" VARCHAR(255),
  "serial_port" VARCHAR(50),
  "baud_rate" INTEGER NOT NULL DEFAULT 9600,
  "fw_code" VARCHAR(50),
  "fw_version" VARCHAR(50),
  "long_fw" VARCHAR(255),
  "hw_version" VARCHAR(50),
  "me_version" VARCHAR(50),
  "dev_eui" VARCHAR(64),
  "app_eui" VARCHAR(64),
  "app_key" VARCHAR(64),
  "region_code" VARCHAR(50),
  "class_mode" VARCHAR(20),
  "sensor_type" VARCHAR(50),
  "serial_number" VARCHAR(100),
  "device_name" VARCHAR(255),
  "raw_registers_snapshot" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "application_id" VARCHAR(100),
  "device_profile_id" VARCHAR(100),
  "chirpstack_payload" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "step" INTEGER NOT NULL DEFAULT 1,
  "status" VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  "message" TEXT,
  "error_detail" TEXT,
  "device_id" UUID,
  "is_reference" BOOLEAN NOT NULL DEFAULT false,
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'tester',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE system_schema."device_test_registrations"
  ADD COLUMN IF NOT EXISTS "application_id" VARCHAR(100),
  ADD COLUMN IF NOT EXISTS "device_profile_id" VARCHAR(100),
  ADD COLUMN IF NOT EXISTS "is_reference" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS "long_fw" VARCHAR(255);

CREATE INDEX IF NOT EXISTS "idx_dtest_reg_dev_eui" ON system_schema."device_test_registrations"("dev_eui");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_serial_number" ON system_schema."device_test_registrations"("serial_number");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_so_number" ON system_schema."device_test_registrations"("so_number");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_wa_number" ON system_schema."device_test_registrations"("wa_number");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_item_code" ON system_schema."device_test_registrations"("item_code");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_status" ON system_schema."device_test_registrations"("status");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_created_at" ON system_schema."device_test_registrations"("created_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_registers_gin" ON system_schema."device_test_registrations" USING GIN ("raw_registers_snapshot");

DROP VIEW IF EXISTS system_schema.v_device_test_registrations_detail CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_test_registrations_detail AS
SELECT * FROM system_schema."device_test_registrations";

-- 011: List Device Testing indexes and view
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_app_id"
  ON system_schema."device_test_registrations" ("application_id");

CREATE INDEX IF NOT EXISTS "idx_dtest_reg_created_by"
  ON system_schema."device_test_registrations" ("created_by");

CREATE INDEX IF NOT EXISTS "idx_dtest_reg_user_app"
  ON system_schema."device_test_registrations" ("created_by", "application_id", "created_at" DESC);

CREATE INDEX IF NOT EXISTS "idx_dtest_reg_admin_app"
  ON system_schema."device_test_registrations" ("application_id", "created_at" DESC);

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
  COALESCE(r."is_reference", false) AS "is_reference"
FROM system_schema."device_test_registrations" r
LEFT JOIN lorawan_chirpstack."network_servers" ns
  ON (r."network_server_id" = ns."id");

-- View for Reference Devices (Golden Reference)
DROP VIEW IF EXISTS system_schema.v_reference_devices CASCADE;
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

-- 012: Device Test Batches and Batch Items (Create Test Batch & Device Test Batch)
CREATE TABLE IF NOT EXISTS system_schema."device_test_batches" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "batch_code" VARCHAR(100) NOT NULL UNIQUE,
  "batch_name" VARCHAR(255) NOT NULL,
  "item_code" VARCHAR(100) NOT NULL,
  "long_fw" VARCHAR(255) NOT NULL,
  "fw_version" VARCHAR(100),
  "simu_id" VARCHAR(100),
  "simulation_flow" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "flow_duration_seconds" INTEGER NOT NULL DEFAULT 600,
  "auto_check_criteria" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "max_devices" INTEGER NOT NULL DEFAULT 10,
  "status" VARCHAR(50) NOT NULL DEFAULT 'CREATED',
  "verdict" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  "duration_seconds" INTEGER NOT NULL DEFAULT 0,
  "started_at" TIMESTAMPTZ,
  "finished_at" TIMESTAMPTZ,
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'tester',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- Allow legacy orphan IDs, but protect all valid links and new batch writes.
UPDATE system_schema.device_test_batches b
SET simu_id = p.simu_id
FROM system_schema.simulation_profiles p
WHERE b.simu_id = p.id::text
  AND NOT EXISTS (
    SELECT 1 FROM system_schema.simulation_profiles canonical
    WHERE canonical.simu_id = b.simu_id
  );
UPDATE system_schema.device_test_batches SET simu_id = NULL WHERE btrim(simu_id) = '';
CREATE INDEX IF NOT EXISTS idx_dtest_batches_simu_id
  ON system_schema.device_test_batches (simu_id);
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'fk_device_test_batches_simulation_flow'
      AND conrelid = 'system_schema.device_test_batches'::regclass
  ) THEN
    ALTER TABLE system_schema.device_test_batches
      ADD CONSTRAINT fk_device_test_batches_simulation_flow
      FOREIGN KEY (simu_id) REFERENCES system_schema.simulation_profiles (simu_id)
      ON DELETE RESTRICT NOT VALID;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS system_schema."device_test_batch_items" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "batch_id" UUID NOT NULL REFERENCES system_schema."device_test_batches"("id") ON DELETE CASCADE,
  "device_test_registration_id" UUID REFERENCES system_schema."device_test_registrations"("id") ON DELETE SET NULL,
  "serial_number" VARCHAR(100) NOT NULL,
  "dev_eui" VARCHAR(64) NOT NULL,
  "item_code" VARCHAR(100) NOT NULL,
  "fw_version" VARCHAR(100),
  "reference_device_id" UUID,
  "reference_serial_number" VARCHAR(100),
  "reference_dev_eui" VARCHAR(64),
  "reference_device_name" VARCHAR(255),
  "status" VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  "verdict" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  "dut_values" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "reference_values" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "comparison_result" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "packets_received" INTEGER NOT NULL DEFAULT 0,
  "rules_passed" INTEGER NOT NULL DEFAULT 0,
  "rules_failed" INTEGER NOT NULL DEFAULT 0,
  "logs" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_dtest_batches_item_fw"
  ON system_schema."device_test_batches" ("item_code", "long_fw");

CREATE INDEX IF NOT EXISTS "idx_dtest_batches_status"
  ON system_schema."device_test_batches" ("status");

CREATE INDEX IF NOT EXISTS "idx_dtest_batch_items_batch_id"
  ON system_schema."device_test_batch_items" ("batch_id");

CREATE INDEX IF NOT EXISTS "idx_dtest_batch_items_serial"
  ON system_schema."device_test_batch_items" ("serial_number");

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
  i."logs",
  i."created_at",
  i."updated_at"
FROM system_schema."device_test_batch_items" i
JOIN system_schema."device_test_batches" b
  ON i."batch_id" = b."id";

-- 014: Device Payload Live View and Menu
DROP VIEW IF EXISTS system_schema.v_device_payload_live CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_payload_live AS
SELECT
  p."id",
  p."device_id",
  COALESCE(p."dev_eui", d."network_id", r."dev_eui") AS "dev_eui",
  COALESCE(d."serial_number", r."serial_number") AS "serial_number",
  COALESCE(d."device_name", r."device_name", r."serial_number", p."dev_eui") AS "device_name",
  COALESCE(d."item_code", r."item_code") AS "item_code",
  COALESCE(r."long_fw", r."fw_version") AS "fw_version",
  r."hw_version",
  p."packet_type",
  p."f_port",
  COALESCE(p."f_cnt", (p."rf_info"->>'fcnt')::BIGINT, (p."rf_info"->>'f_cnt')::BIGINT, 0) AS "f_cnt",
  COALESCE(p."rssi", (p."rf_info"->>'rssi')::DOUBLE PRECISION) AS "rssi",
  COALESCE(p."snr", (p."rf_info"->>'snr')::DOUBLE PRECISION) AS "snr",
  COALESCE(p."sf", p."rf_info"->>'sf', p."rf_info"->>'spreading_factor', p."rf_info"->>'spreadingFactor', 'SF7') AS "sf",
  COALESCE(p."frequency", (p."rf_info"->>'frequency')::DOUBLE PRECISION) AS "frequency",
  p."raw_payload",
  p."decoded_payload",
  p."rf_info",
  p."created_at"
FROM system_schema."device_packets" p
LEFT JOIN system_schema."devices" d
  ON p."device_id" = d."id"
LEFT JOIN system_schema."device_test_registrations" r
  ON (p."dev_eui" = r."dev_eui" OR d."network_id" = r."dev_eui");

INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES (
  'testing:device-payload',
  'Device Payload',
  'Bảng dữ liệu nhận và giải mã payload từ ChirpStack HTTP Integration theo từng loại cảm biến',
  '/plugins/testing?tab=device-payload',
  'Activity',
  'plugin',
  'testing',
  'device-payload',
  16,
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









-- Persist AutoCheck configurations independently from execution/session snapshots.
-- The public ID is generated by PostgreSQL, never supplied by the form.
CREATE TABLE IF NOT EXISTS system_schema.device_autocheck_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  autocheck_id VARCHAR(40) NOT NULL UNIQUE DEFAULT ('AC-' || upper(replace(gen_random_uuid()::text, '-', ''))),
  name VARCHAR(255) NOT NULL CHECK (btrim(name) <> ''),
  item_code VARCHAR(100) NOT NULL CHECK (btrim(item_code) <> ''),
  fw_version VARCHAR(100) NOT NULL CHECK (btrim(fw_version) <> ''),
  reference_item_code VARCHAR(100),
  reference_fw_version VARCHAR(100),
  criteria JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(criteria) = 'object'),
  created_by VARCHAR(100) NOT NULL DEFAULT 'tester',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (
    (reference_item_code IS NULL AND reference_fw_version IS NULL)
    OR (reference_item_code IS NOT NULL AND btrim(reference_item_code) <> ''
        AND reference_fw_version IS NOT NULL AND btrim(reference_fw_version) <> '')
  )
);

CREATE INDEX IF NOT EXISTS idx_autocheck_profiles_product
  ON system_schema.device_autocheck_profiles (item_code, fw_version);

CREATE INDEX IF NOT EXISTS "idx_autocheck_profiles_criteria_gin"
  ON system_schema."device_autocheck_profiles" USING GIN ("criteria");

CREATE INDEX IF NOT EXISTS "idx_autocheck_profiles_created_at"
  ON system_schema."device_autocheck_profiles" ("created_at" DESC);

DROP VIEW IF EXISTS system_schema.v_device_autocheck_profiles CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_autocheck_profiles AS
SELECT
  p."id",
  p."autocheck_id",
  p."name",
  p."item_code",
  p."fw_version",
  p."reference_item_code",
  p."reference_fw_version",
  (p."reference_item_code" IS NOT NULL AND btrim(p."reference_item_code") <> '') AS "requires_reference",
  p."criteria",
  jsonb_array_length(
    CASE
      WHEN jsonb_typeof(p."criteria"->'rules') = 'array' THEN p."criteria"->'rules'
      WHEN jsonb_typeof(p."criteria"->'customRules') = 'array' THEN p."criteria"->'customRules'
      ELSE '[]'::jsonb
    END
  ) AS "rule_count",
  p."created_by",
  p."created_at",
  p."updated_at"
FROM system_schema."device_autocheck_profiles" p;

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema.device_autocheck_profiles TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_autocheck_profiles TO itest_system_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema.device_autocheck_profiles TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_autocheck_profiles TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.v_device_autocheck_profiles TO itest_ops_user;
  END IF;
END $$;

-- 15. View for Flow Simulations
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

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_system_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_ops_user;
  END IF;
END $$;

-- 16. View for Simulation Devices (excludes template records)
DROP VIEW IF EXISTS system_schema.v_simulation_devices CASCADE;
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
WHERE d."status" = 'simulation';

COMMENT ON VIEW system_schema.v_simulation_devices IS 'View danh sách các thiết bị kiểm thử simulation thực tế (không bao gồm template)';

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_system_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_ops_user;
  END IF;
END $$;

-- ==============================================================================
-- 17. SO Test Batches Linking Table & Views (Plugin: so-test-batch)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS system_schema."so_test_batches" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "so_id" UUID NOT NULL REFERENCES traceability_manager."traceability_so"("id") ON DELETE CASCADE,
  "batch_id" UUID NOT NULL REFERENCES system_schema."device_test_batches"("id") ON DELETE CASCADE,
  "so_number" VARCHAR(50) NOT NULL,
  "batch_code" VARCHAR(100) NOT NULL,
  "item_code" VARCHAR(100),
  "notes" TEXT,
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'operator',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT uq_so_test_batches_so_batch UNIQUE ("so_id", "batch_id"),
  CONSTRAINT uq_so_test_batches_number_code UNIQUE ("so_number", "batch_code")
);

COMMENT ON TABLE system_schema."so_test_batches" IS 'Bảng liên kết quan hệ 1-N giữa Đơn Bán Hàng (SO) và các Đợt kiểm thử lô (Device Test Batches) theo từng ITEM_CODE';

CREATE INDEX IF NOT EXISTS "idx_so_test_batches_so_id" ON system_schema."so_test_batches" ("so_id");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_batch_id" ON system_schema."so_test_batches" ("batch_id");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_so_number" ON system_schema."so_test_batches" ("so_number");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_batch_code" ON system_schema."so_test_batches" ("batch_code");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_item_code" ON system_schema."so_test_batches" ("item_code");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_so_item" ON system_schema."so_test_batches" ("so_id", "item_code");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_created_at" ON system_schema."so_test_batches" ("created_at" DESC);

CREATE OR REPLACE FUNCTION system_schema.sync_so_test_batches_codes()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.so_number IS NULL OR NEW.so_number = '' THEN
    SELECT so_number INTO NEW.so_number FROM traceability_manager.traceability_so WHERE id = NEW.so_id;
  END IF;
  IF NEW.batch_code IS NULL OR NEW.batch_code = '' THEN
    SELECT batch_code, item_code INTO NEW.batch_code, NEW.item_code FROM system_schema.device_test_batches WHERE id = NEW.batch_id;
  END IF;
  IF NEW.item_code IS NULL OR NEW.item_code = '' THEN
    SELECT item_code INTO NEW.item_code FROM system_schema.device_test_batches WHERE id = NEW.batch_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_so_test_batches_codes ON system_schema."so_test_batches";
CREATE TRIGGER trg_sync_so_test_batches_codes
BEFORE INSERT OR UPDATE ON system_schema."so_test_batches"
FOR EACH ROW
EXECUTE FUNCTION system_schema.sync_so_test_batches_codes();

DROP TRIGGER IF EXISTS trg_so_test_batches_updated_at ON system_schema."so_test_batches";
CREATE TRIGGER trg_so_test_batches_updated_at
BEFORE UPDATE ON system_schema."so_test_batches"
FOR EACH ROW
EXECUTE FUNCTION system_schema.set_current_timestamp_updated_at();

-- Detailed View
CREATE OR REPLACE VIEW system_schema.v_so_test_batches_detail AS
SELECT
  sotb."id" AS "link_id",
  sotb."so_id",
  so."so_number",
  so."customer_name",
  so."customer_email",
  so."partner_email",
  so."created_at" AS "so_created_at",
  sotb."batch_id",
  b."batch_code",
  b."batch_name",
  COALESCE(sotb."item_code", b."item_code") AS "item_code",
  b."long_fw",
  b."fw_version",
  b."simu_id",
  b."flow_duration_seconds",
  b."max_devices",
  b."status" AS "batch_status",
  b."verdict" AS "batch_verdict",
  b."duration_seconds",
  b."started_at" AS "batch_started_at",
  b."finished_at" AS "batch_finished_at",
  COALESCE(
    (SELECT COUNT(*)::int FROM system_schema."device_test_batch_items" bi WHERE bi."batch_id" = b."id"),
    0
  ) AS "device_count",
  sotb."created_at" AS "linked_at",
  sotb."created_by" AS "linked_by",
  sotb."notes",
  sotb."metadata"
FROM system_schema."so_test_batches" sotb
JOIN traceability_manager."traceability_so" so ON sotb."so_id" = so."id"
JOIN system_schema."device_test_batches" b ON sotb."batch_id" = b."id";

-- Aggregated View for Tabulator
CREATE OR REPLACE VIEW system_schema.v_so_with_test_batches AS
SELECT
  so."id" AS "so_id",
  so."so_number",
  so."customer_name",
  so."customer_email",
  so."partner_email",
  so."notes",
  so."created_at",
  so."updated_at",
  COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'linkId', sotb."id",
        'batchId', b."id",
        'batchCode', b."batch_code",
        'batchName', b."batch_name",
        'itemCode', COALESCE(sotb."item_code", b."item_code"),
        'longFw', b."long_fw",
        'fwVersion', b."fw_version",
        'status', b."status",
        'verdict', b."verdict",
        'deviceCount', COALESCE((SELECT COUNT(*)::int FROM system_schema."device_test_batch_items" bi WHERE bi."batch_id" = b."id"), 0),
        'linkedAt', sotb."created_at",
        'linkedBy', sotb."created_by"
      ) ORDER BY sotb."created_at" DESC
    ) FILTER (WHERE b."id" IS NOT NULL),
    '[]'::jsonb
  ) AS "test_batches",
  COALESCE(
    (
      SELECT JSONB_AGG(DISTINCT sub_b."item_code")
      FROM system_schema."so_test_batches" sub_sotb
      JOIN system_schema."device_test_batches" sub_b ON sub_sotb."batch_id" = sub_b."id"
      WHERE sub_sotb."so_id" = so."id" AND sub_b."item_code" IS NOT NULL
    ),
    '[]'::jsonb
  ) AS "item_codes",
  COUNT(sotb."id")::int AS "test_batch_count"
FROM traceability_manager."traceability_so" so
LEFT JOIN system_schema."so_test_batches" sotb ON so."id" = sotb."so_id"
LEFT JOIN system_schema."device_test_batches" b ON sotb."batch_id" = b."id"
GROUP BY so."id", so."so_number", so."customer_name", so."customer_email", so."partner_email", so."notes", so."created_at", so."updated_at";

-- Available Batches View
CREATE OR REPLACE VIEW system_schema.v_available_test_batches AS
SELECT
  b."id",
  b."batch_code",
  b."batch_name",
  b."item_code",
  b."long_fw",
  b."fw_version",
  b."simu_id",
  b."flow_duration_seconds",
  b."max_devices",
  b."status",
  b."verdict",
  b."duration_seconds",
  b."started_at",
  b."finished_at",
  b."created_by",
  b."created_at",
  COALESCE(
    (SELECT COUNT(*)::int FROM system_schema."device_test_batch_items" bi WHERE bi."batch_id" = b."id"),
    0
  ) AS "device_count"
FROM system_schema."device_test_batches" b;

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."so_test_batches" TO itest_system_user;
    GRANT SELECT ON system_schema.v_so_test_batches_detail TO itest_system_user;
    GRANT SELECT ON system_schema.v_so_with_test_batches TO itest_system_user;
    GRANT SELECT ON system_schema.v_available_test_batches TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."so_test_batches" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_so_test_batches_detail TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_so_with_test_batches TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_available_test_batches TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON TABLE system_schema."so_test_batches" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_so_test_batches_detail TO itest_ops_user;
    GRANT SELECT ON system_schema.v_so_with_test_batches TO itest_ops_user;
    GRANT SELECT ON system_schema.v_available_test_batches TO itest_ops_user;
  END IF;
END $$;




