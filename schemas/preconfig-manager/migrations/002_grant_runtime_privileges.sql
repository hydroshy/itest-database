-- ==============================================================================
-- MIGRATION: 002_grant_runtime_privileges.sql
-- Module: preconfig-manager
-- Schema: preconfig_manager
-- Description: Grants USAGE, SELECT, INSERT, UPDATE, DELETE permissions for
--              schema preconfig_manager. Idempotent and safe for volume upgrades.
-- ==============================================================================

DO $$
BEGIN
  -- Grant to itest_system_user (Backend API runtime)
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE ON SCHEMA preconfig_manager TO itest_system_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA preconfig_manager TO itest_system_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA preconfig_manager TO itest_system_user;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA preconfig_manager TO itest_system_user;
  END IF;

  -- Grant to itest_plugins_user (Plugin microservice runtime)
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE ON SCHEMA preconfig_manager TO itest_plugins_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA preconfig_manager TO itest_plugins_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA preconfig_manager TO itest_plugins_user;
  END IF;

  -- Grant to itest_plugin_user (Single plugin sandbox user)
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT USAGE ON SCHEMA preconfig_manager TO itest_plugin_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA preconfig_manager TO itest_plugin_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA preconfig_manager TO itest_plugin_user;
  END IF;

  -- Set DEFAULT PRIVILEGES for future tables created in preconfig_manager
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA preconfig_manager
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_system_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA preconfig_manager
      GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_system_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA preconfig_manager
      GRANT EXECUTE ON FUNCTIONS TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA preconfig_manager
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_plugins_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA preconfig_manager
      GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA preconfig_manager
      GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_plugin_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA preconfig_manager
      GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_plugin_user;
  END IF;
END $$;
