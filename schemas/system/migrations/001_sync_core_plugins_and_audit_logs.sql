-- ==============================================================================
-- MIGRATION: 001_sync_core_plugins_and_audit_logs.sql
-- Description: Align system_schema.core_plugins and plugin_audit_logs with
--              CorePluginEntity and PluginAuditLogEntity in itest-system.
-- Schema: system_schema
-- Idempotency: Safe to re-run on existing volumes.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Ensure table core_plugins exists with base columns
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

-- 2. Alter existing core_plugins table if it was created with old schema
DO $$
BEGIN
  -- Handle 'type'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'type'
  ) THEN
    ALTER TABLE system_schema."core_plugins" ADD COLUMN "type" VARCHAR(64) NOT NULL DEFAULT 'SYSTEM';
  END IF;

  -- Handle 'schemaName' (or schema_name)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'schemaName'
  ) THEN
    ALTER TABLE system_schema."core_plugins" ADD COLUMN "schemaName" VARCHAR(128) NOT NULL DEFAULT 'public';
  END IF;

  -- Handle 'status' length adjustment if needed
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'status'
  ) THEN
    ALTER TABLE system_schema."core_plugins" ALTER COLUMN "status" TYPE VARCHAR(32);
    ALTER TABLE system_schema."core_plugins" ALTER COLUMN "status" SET DEFAULT 'ACTIVE';
  END IF;

  -- Handle 'repositoryUrl'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'repositoryUrl'
  ) THEN
    ALTER TABLE system_schema."core_plugins" ADD COLUMN "repositoryUrl" VARCHAR(512);
  END IF;

  -- Handle 'bundleUrl'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'bundleUrl'
  ) THEN
    ALTER TABLE system_schema."core_plugins" ADD COLUMN "bundleUrl" VARCHAR(512);
  END IF;

  -- Handle 'bundleType'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'bundleType'
  ) THEN
    ALTER TABLE system_schema."core_plugins" ADD COLUMN "bundleType" VARCHAR(32) DEFAULT 'ESM';
  END IF;

  -- Handle 'manifest'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'manifest'
  ) THEN
    ALTER TABLE system_schema."core_plugins" ADD COLUMN "manifest" JSONB DEFAULT '{}';
  END IF;

  -- Handle 'uiEntry'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'uiEntry'
  ) THEN
    ALTER TABLE system_schema."core_plugins" ADD COLUMN "uiEntry" JSONB;
  END IF;

  -- Handle 'backendEntry'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'backendEntry'
  ) THEN
    ALTER TABLE system_schema."core_plugins" ADD COLUMN "backendEntry" JSONB;
  END IF;

  -- Handle 'permissions'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'permissions'
  ) THEN
    ALTER TABLE system_schema."core_plugins" ADD COLUMN "permissions" JSONB DEFAULT '[]';
  END IF;

  -- Handle 'createdAt'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'createdAt'
  ) THEN
    -- If old column installed_at exists, copy over
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'installed_at'
    ) THEN
      ALTER TABLE system_schema."core_plugins" ADD COLUMN "createdAt" TIMESTAMP NOT NULL DEFAULT now();
      UPDATE system_schema."core_plugins" SET "createdAt" = "installed_at" WHERE "installed_at" IS NOT NULL;
    ELSE
      ALTER TABLE system_schema."core_plugins" ADD COLUMN "createdAt" TIMESTAMP NOT NULL DEFAULT now();
    END IF;
  END IF;

  -- Handle 'updatedAt'
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'updatedAt'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'updated_at'
    ) THEN
      ALTER TABLE system_schema."core_plugins" ADD COLUMN "updatedAt" TIMESTAMP NOT NULL DEFAULT now();
      UPDATE system_schema."core_plugins" SET "updatedAt" = "updated_at" WHERE "updated_at" IS NOT NULL;
    ELSE
      ALTER TABLE system_schema."core_plugins" ADD COLUMN "updatedAt" TIMESTAMP NOT NULL DEFAULT now();
    END IF;
  END IF;

  -- Backfill manifest/type from category/config if present
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'category'
  ) THEN
    UPDATE system_schema."core_plugins"
    SET "type" = CASE
      WHEN UPPER("category") = 'PROTOCOL' THEN 'PROTOCOL'
      WHEN UPPER("category") = 'ANALYTICS' THEN 'ANALYTICS'
      WHEN UPPER("category") = 'DRIVER' THEN 'DRIVER'
      ELSE 'SYSTEM'
    END
    WHERE "type" IS NULL OR "type" = 'SYSTEM';
  END IF;

  -- Handle Primary Key / ID type: If id is UUID and plugin_id exists, adapt id to VARCHAR
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'id' AND data_type = 'uuid'
  ) THEN
    -- If plugin_id column exists, populate id with plugin_id before changing type
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'system_schema' AND table_name = 'core_plugins' AND column_name = 'plugin_id'
    ) THEN
      ALTER TABLE system_schema."core_plugins" ALTER COLUMN "id" TYPE VARCHAR(128) USING COALESCE("plugin_id", "id"::text);
    ELSE
      ALTER TABLE system_schema."core_plugins" ALTER COLUMN "id" TYPE VARCHAR(128) USING "id"::text;
    END IF;
  END IF;
END $$;

-- 3. Ensure indexes for core_plugins
CREATE INDEX IF NOT EXISTS "idx_core_plugins_type" ON system_schema."core_plugins"("type");
CREATE INDEX IF NOT EXISTS "idx_core_plugins_status" ON system_schema."core_plugins"("status");

-- 4. Align plugin_audit_logs with PluginAuditLogEntity
CREATE TABLE IF NOT EXISTS system_schema."plugin_audit_logs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "pluginId" VARCHAR(128) NOT NULL,
  "version" VARCHAR(64) NOT NULL DEFAULT '1.0.0',
  "action" VARCHAR(32) NOT NULL,
  "operator" VARCHAR(128) NOT NULL DEFAULT 'system',
  "details" JSONB DEFAULT '{}',
  "createdAt" TIMESTAMP NOT NULL DEFAULT now()
);

DO $$
BEGIN
  -- Handle pluginId column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'plugin_audit_logs' AND column_name = 'pluginId'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'system_schema' AND table_name = 'plugin_audit_logs' AND column_name = 'plugin_id'
    ) THEN
      ALTER TABLE system_schema."plugin_audit_logs" ADD COLUMN "pluginId" VARCHAR(128);
      UPDATE system_schema."plugin_audit_logs" SET "pluginId" = "plugin_id";
      ALTER TABLE system_schema."plugin_audit_logs" ALTER COLUMN "pluginId" SET NOT NULL;
    ELSE
      ALTER TABLE system_schema."plugin_audit_logs" ADD COLUMN "pluginId" VARCHAR(128) NOT NULL DEFAULT 'unknown';
    END IF;
  END IF;

  -- Handle version column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'plugin_audit_logs' AND column_name = 'version'
  ) THEN
    ALTER TABLE system_schema."plugin_audit_logs" ADD COLUMN "version" VARCHAR(64) NOT NULL DEFAULT '1.0.0';
  END IF;

  -- Handle operator column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'plugin_audit_logs' AND column_name = 'operator'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'system_schema' AND table_name = 'plugin_audit_logs' AND column_name = 'actor'
    ) THEN
      ALTER TABLE system_schema."plugin_audit_logs" ADD COLUMN "operator" VARCHAR(128);
      UPDATE system_schema."plugin_audit_logs" SET "operator" = "actor";
      ALTER TABLE system_schema."plugin_audit_logs" ALTER COLUMN "operator" SET NOT NULL;
    ELSE
      ALTER TABLE system_schema."plugin_audit_logs" ADD COLUMN "operator" VARCHAR(128) NOT NULL DEFAULT 'system';
    END IF;
  END IF;

  -- Handle createdAt column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'system_schema' AND table_name = 'plugin_audit_logs' AND column_name = 'createdAt'
  ) THEN
    IF EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'system_schema' AND table_name = 'plugin_audit_logs' AND column_name = 'created_at'
    ) THEN
      ALTER TABLE system_schema."plugin_audit_logs" ADD COLUMN "createdAt" TIMESTAMP NOT NULL DEFAULT now();
      UPDATE system_schema."plugin_audit_logs" SET "createdAt" = "created_at";
    ELSE
      ALTER TABLE system_schema."plugin_audit_logs" ADD COLUMN "createdAt" TIMESTAMP NOT NULL DEFAULT now();
    END IF;
  END IF;
END $$;

-- 5. Ensure indexes on plugin_audit_logs
CREATE INDEX IF NOT EXISTS "idx_plugin_audit_plugin_id" ON system_schema."plugin_audit_logs"("pluginId");
CREATE INDEX IF NOT EXISTS "idx_plugin_audit_action" ON system_schema."plugin_audit_logs"("action");
