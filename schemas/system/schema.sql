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
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "plugin_id" VARCHAR(100) UNIQUE NOT NULL,
  "name" VARCHAR(255) NOT NULL,
  "version" VARCHAR(50) NOT NULL,
  "description" TEXT,
  "author" VARCHAR(255),
  "license" VARCHAR(100),
  "category" VARCHAR(100) NOT NULL,
  "enabled" BOOLEAN NOT NULL DEFAULT false,
  "status" VARCHAR(50) NOT NULL DEFAULT 'installed',
  "entry_point" VARCHAR(255) NOT NULL,
  "config" JSONB DEFAULT '{}',
  "dependencies" JSONB DEFAULT '{}',
  "installed_at" TIMESTAMP NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMP NOT NULL DEFAULT now()
);

-- 7. Plugin Security and Operation Audit Logs
CREATE TABLE IF NOT EXISTS system_schema."plugin_audit_logs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "plugin_id" VARCHAR(100) NOT NULL,
  "action" VARCHAR(100) NOT NULL,
  "actor" VARCHAR(255) NOT NULL,
  "details" JSONB DEFAULT '{}',
  "created_at" TIMESTAMP NOT NULL DEFAULT now()
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
CREATE INDEX IF NOT EXISTS "idx_core_plugins_id" ON system_schema."core_plugins"("plugin_id");
CREATE INDEX IF NOT EXISTS "idx_core_plugins_status" ON system_schema."core_plugins"("status");
CREATE INDEX IF NOT EXISTS "idx_plugin_audit_plugin_id" ON system_schema."plugin_audit_logs"("plugin_id");
CREATE INDEX IF NOT EXISTS "idx_plugin_audit_created_at" ON system_schema."plugin_audit_logs"("created_at" DESC);
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