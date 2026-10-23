-- ==============================================================================
-- MIGRATION: 003_create_menu_items_and_role_permissions.sql
-- Description: Create menu_items catalog, role_menu_permissions matrix, seed
--              granular plugin features/tabs, and grant runtime privileges.
-- Schema: system_schema
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Ensure Standard Roles exist in system_schema.roles
INSERT INTO system_schema."roles" ("code", "name", "description")
VALUES
  ('SUPER_ADMIN', 'Super Admin', 'Full administrative access to all system features and plugins'),
  ('admin', 'Admin', 'Full administrative access to micro-kernel core'),
  ('SUB_ADMIN', 'Sub-Admin', 'Delegated administrative privileges'),
  ('sub_admin', 'Sub-Admin', 'Delegated administrative privileges'),
  ('OPERATOR', 'Operator', 'Operational, testing and device execution access'),
  ('operator', 'Operator', 'Operational, testing and device execution access'),
  ('END_USER', 'End User', 'Standard end user with access to assigned tools'),
  ('user', 'User', 'Standard user')
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
  -- Sync pluginId / plugin_id
  IF NEW."pluginId" IS NOT NULL AND NEW."plugin_id" IS NULL THEN
    NEW."plugin_id" := NEW."pluginId";
  ELSIF NEW."plugin_id" IS NOT NULL AND NEW."pluginId" IS NULL THEN
    NEW."pluginId" := NEW."plugin_id";
  END IF;

  -- Sync order / display_order
  IF NEW."order" IS NOT NULL AND (NEW."display_order" IS NULL OR NEW."display_order" = 0) THEN
    NEW."display_order" := NEW."order";
  ELSIF NEW."display_order" IS NOT NULL AND (NEW."order" IS NULL OR NEW."order" = 0) THEN
    NEW."order" := NEW."display_order";
  END IF;

  -- Sync isActive / is_active
  IF NEW."isActive" IS NOT NULL THEN
    NEW."is_active" := NEW."isActive";
  ELSIF NEW."is_active" IS NOT NULL THEN
    NEW."isActive" := NEW."is_active";
  END IF;

  -- Sync timestamps
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

-- Indexes for menu_items
CREATE INDEX IF NOT EXISTS "idx_menu_items_category" ON system_schema."menu_items"("category");
CREATE INDEX IF NOT EXISTS "idx_menu_items_plugin_id" ON system_schema."menu_items"("plugin_id");
CREATE INDEX IF NOT EXISTS "idx_menu_items_pluginId" ON system_schema."menu_items"("pluginId");
CREATE INDEX IF NOT EXISTS "idx_menu_items_order" ON system_schema."menu_items"("order");
CREATE INDEX IF NOT EXISTS "idx_menu_items_is_active" ON system_schema."menu_items"("isActive");

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

DROP TRIGGER IF EXISTS trg_sync_role_menu_permissions ON system_schema."role_menu_permissions";
CREATE TRIGGER trg_sync_role_menu_permissions
BEFORE INSERT OR UPDATE ON system_schema."role_menu_permissions"
FOR EACH ROW
EXECUTE FUNCTION system_schema.sync_role_menu_permissions();

-- Indexes for role_menu_permissions
CREATE INDEX IF NOT EXISTS "idx_role_menu_role_id" ON system_schema."role_menu_permissions"("roleId");
CREATE INDEX IF NOT EXISTS "idx_role_menu_role_id_snake" ON system_schema."role_menu_permissions"("role_id");
CREATE INDEX IF NOT EXISTS "idx_role_menu_role_code" ON system_schema."role_menu_permissions"("roleCode");
CREATE INDEX IF NOT EXISTS "idx_role_menu_role_code_snake" ON system_schema."role_menu_permissions"("role_code");
CREATE INDEX IF NOT EXISTS "idx_role_menu_menu_item_id" ON system_schema."role_menu_permissions"("menuItemId");
CREATE INDEX IF NOT EXISTS "idx_role_menu_menu_item_id_snake" ON system_schema."role_menu_permissions"("menu_item_id");

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
  ('lorawan-chirpstack:integration', 'LoRaWAN ChirpStack Integration', 'Đồng bộ thiết bị và cấu hình kết nối ChirpStack v4', '/plugins/lorawan-chirpstack', 'Connection', 'plugin', 'lorawan-chirpstack', 'integration', 9, true)
ON CONFLICT ("id") DO UPDATE SET
  "title" = EXCLUDED."title",
  "description" = EXCLUDED."description",
  "route" = EXCLUDED."route",
  "icon" = EXCLUDED."icon",
  "category" = EXCLUDED."category",
  "pluginId" = EXCLUDED."pluginId",
  "plugin_id" = EXCLUDED."pluginId",
  "tab" = EXCLUDED."tab",
  "order" = EXCLUDED."order",
  "display_order" = EXCLUDED."order",
  "isActive" = EXCLUDED."isActive",
  "is_active" = EXCLUDED."isActive",
  "updatedAt" = now(),
  "updated_at" = now();

-- 5. Seed Default Role Menu Permissions Matrix
-- A. SUPER_ADMIN & admin: All menu items
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUPER_ADMIN', 'admin')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- B. SUB_ADMIN & sub_admin: Operational & management items
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('SUB_ADMIN', 'sub_admin')
  AND m."id" IN ('dashboard', 'final-config:tool', 'final-config:manager', 'device-traceability:so', 'device-traceability:devices', 'device-traceability:config', 'memmap-payload:manager')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- C. OPERATOR & operator: Test, traceability, and LoRaWAN operations
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('OPERATOR', 'operator')
  AND m."id" IN ('final-config:tool', 'device-traceability:devices', 'lorawan-chirpstack:integration')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- D. END_USER & user: Final Config Tool only (isolated tool access)
INSERT INTO system_schema."role_menu_permissions" ("roleId", "roleCode", "menuItemId")
SELECT r."id", r."code", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('END_USER', 'user')
  AND m."id" IN ('final-config:tool')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 6. Add Fine-Grained Permissions into system_schema.permission
INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  ('system:menu:manage', 'Manage menu cards and role assignments', 'system', 'manage'),
  ('menu:dashboard:view', 'Access Dashboard card', 'menu', 'read'),
  ('menu:final-config-tool:view', 'Access Final Config Tool card', 'menu', 'read'),
  ('menu:final-config-manager:view', 'Access Final Config Manager card', 'menu', 'read'),
  ('menu:final-config-create:view', 'Access Final Config Create card', 'menu', 'read'),
  ('menu:device-traceability-so:view', 'Access Sales Orders & WA card', 'menu', 'read'),
  ('menu:device-traceability-devices:view', 'Access Device Traceability card', 'menu', 'read'),
  ('menu:device-traceability-config:view', 'Access Device Traceability Config card', 'menu', 'read'),
  ('menu:memmap-payload-manager:view', 'Access Memmap Profiles card', 'menu', 'read'),
  ('menu:lorawan-chirpstack-integration:view', 'Access LoRaWAN ChirpStack card', 'menu', 'read')
ON CONFLICT ("name") DO UPDATE SET
  "description" = EXCLUDED."description",
  "module" = EXCLUDED."module",
  "action" = EXCLUDED."action";

-- Assign system:menu:manage to SUPER_ADMIN and admin
INSERT INTO system_schema."role_permissions" ("role_id", "permission_id")
SELECT r."id", p."id"
FROM system_schema."roles" r, system_schema."permission" p
WHERE r."code" IN ('SUPER_ADMIN', 'admin')
  AND p."name" = 'system:menu:manage'
ON CONFLICT ("role_id", "permission_id") DO NOTHING;

-- 7. Grant Idempotent Runtime Privileges
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."menu_items" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."role_menu_permissions" TO itest_system_user;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA system_schema TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_plugins_user;
    GRANT SELECT ON TABLE system_schema."menu_items" TO itest_plugins_user;
    GRANT SELECT ON TABLE system_schema."role_menu_permissions" TO itest_plugins_user;
  END IF;
END $$;
