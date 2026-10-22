-- ==============================================================================
-- MIGRATION: 002_grant_runtime_privileges.sql
-- Module: traceability-manager
-- Description: Runtime grants for existing and future PostgreSQL objects in
--              schema traceability_manager. Idempotent and safe for volume upgrades.
-- ==============================================================================

DO $$
BEGIN
  -- 1. Grants for itest_system_user
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE ON SCHEMA traceability_manager TO itest_system_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA traceability_manager TO itest_system_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA traceability_manager TO itest_system_user;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA traceability_manager TO itest_system_user;
  END IF;

  -- 2. Grants for itest_plugin_user
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT USAGE ON SCHEMA traceability_manager TO itest_plugin_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA traceability_manager TO itest_plugin_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA traceability_manager TO itest_plugin_user;
  END IF;

  -- 3. Grants for itest_plugins_user (plural alias used in core initialization)
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE ON SCHEMA traceability_manager TO itest_plugins_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA traceability_manager TO itest_plugins_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA traceability_manager TO itest_plugins_user;
  END IF;

  -- 4. Grants for itest_ops_user (Read-only access for monitoring & telemetry)
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT USAGE ON SCHEMA traceability_manager TO itest_ops_user;
    GRANT SELECT ON ALL TABLES IN SCHEMA traceability_manager TO itest_ops_user;
  END IF;
END $$;

-- Grants created by future migrations run by the database owner
ALTER DEFAULT PRIVILEGES IN SCHEMA traceability_manager
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_system_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA traceability_manager
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_system_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA traceability_manager
  GRANT EXECUTE ON FUNCTIONS TO itest_system_user;

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA traceability_manager
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_plugin_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA traceability_manager
      GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_plugin_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA traceability_manager
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_plugins_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA traceability_manager
      GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA traceability_manager
      GRANT SELECT ON TABLES TO itest_ops_user;
  END IF;
END $$;
