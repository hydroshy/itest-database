-- ==============================================================================
-- MIGRATION: 032_add_builtin_and_config_to_core_plugins.sql
-- Module: system
-- Schema: system_schema
-- Description: Adds isBuiltIn, lastError, and config columns to core_plugins table
--              to support dynamic plugin registry persistence and offline fallback.
-- ==============================================================================

ALTER TABLE system_schema."core_plugins"
  ADD COLUMN IF NOT EXISTS "isBuiltIn" BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS "lastError" TEXT,
  ADD COLUMN IF NOT EXISTS "config" JSONB DEFAULT '{}';

COMMENT ON COLUMN system_schema."core_plugins"."isBuiltIn" IS 'Indicates whether the plugin is embedded directly into core system build.';
COMMENT ON COLUMN system_schema."core_plugins"."lastError" IS 'Detailed error message if plugin failed during lifecycle initialization or registration.';
COMMENT ON COLUMN system_schema."core_plugins"."config" IS 'Runtime persistent configuration overrides for the plugin.';

GRANT ALL ON TABLE system_schema."core_plugins" TO itest_system_user;
