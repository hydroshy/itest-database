-- ==============================================================================
-- MIGRATION: 002_grant_runtime_privileges.sql
-- Module: finalconfig-manager
-- Description: Runtime grants for existing and future PostgreSQL objects in
--              schema finalconfig_manager. Idempotent and safe for volume upgrades.
-- ==============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE ON SCHEMA finalconfig_manager TO itest_system_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA finalconfig_manager TO itest_system_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA finalconfig_manager TO itest_system_user;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA finalconfig_manager TO itest_system_user;
  END IF;

  -- Plugin user permissions (support canonical itest_plugins_user and alias itest_plugin_user)
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE ON SCHEMA finalconfig_manager TO itest_plugins_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA finalconfig_manager TO itest_plugins_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA finalconfig_manager TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT USAGE ON SCHEMA finalconfig_manager TO itest_plugin_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA finalconfig_manager TO itest_plugin_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA finalconfig_manager TO itest_plugin_user;
  END IF;
END $$;

-- Grants created by future migrations run by the database owner.
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA finalconfig_manager
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_system_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA finalconfig_manager
      GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_system_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA finalconfig_manager
      GRANT EXECUTE ON FUNCTIONS TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA finalconfig_manager
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_plugins_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA finalconfig_manager
      GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA finalconfig_manager
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_plugin_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA finalconfig_manager
      GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_plugin_user;
  END IF;
END $$;
