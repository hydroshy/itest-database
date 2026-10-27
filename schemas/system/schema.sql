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
  "roleId" UUID NOT NULL REFERENCES system_schema."roles"("id") ON DELETE CASCADE,
  "role_id" UUID,
  "roleCode" VARCHAR(100) NOT NULL,
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
BEGIN
  IF NEW."roleId" IS NOT NULL AND NEW."role_id" IS NULL THEN
    NEW."role_id" := NEW."roleId";
  ELSIF NEW."role_id" IS NOT NULL AND NEW."roleId" IS NULL THEN
    NEW."roleId" := NEW."role_id";
  END IF;

  IF NEW."roleCode" IS NOT NULL AND NEW."role_code" IS NULL THEN
    NEW."role_code" := NEW."roleCode";
  ELSIF NEW."role_code" IS NOT NULL AND NEW."roleCode" IS NULL THEN
    NEW."roleCode" := NEW."role_code";
  END IF;

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
CREATE OR REPLACE VIEW system_schema."system_menu_items" AS
SELECT * FROM system_schema."menu_items";

CREATE OR REPLACE VIEW public."system_menu_items" AS
SELECT * FROM system_schema."menu_items";

CREATE OR REPLACE VIEW public."menu_items" AS
SELECT * FROM system_schema."menu_items";

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
  "device_id" UUID NOT NULL REFERENCES system_schema."devices"("id") ON DELETE CASCADE,
  "packet_type" VARCHAR(50) NOT NULL DEFAULT 'uplink',
  "f_port" INTEGER,
  "f_cnt" BIGINT,
  "raw_payload" TEXT,
  "decoded_payload" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "rf_info" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_device_packets_device_id_created_at" ON system_schema."device_packets"("device_id", "created_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_device_packets_packet_type" ON system_schema."device_packets"("packet_type");
CREATE INDEX IF NOT EXISTS "idx_device_packets_decoded_payload_gin" ON system_schema."device_packets" USING GIN ("decoded_payload");
CREATE INDEX IF NOT EXISTS "idx_device_packets_rf_info_gin" ON system_schema."device_packets" USING GIN ("rf_info");

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


