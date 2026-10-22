-- ==============================================================================
-- MIGRATION: 002_grant_system_plugin_privileges.sql
-- Description: Grant idempotent runtime privileges on system_schema to
--              itest_system_user and itest_plugins_user.
-- Schema: system_schema
-- ==============================================================================

DO $$
BEGIN
  -- 1. itest_system_user: full operational privileges on system_schema
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE, CREATE ON SCHEMA system_schema TO itest_system_user;
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA system_schema TO itest_system_user;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA system_schema TO itest_system_user;
    GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA system_schema TO itest_system_user;

    ALTER DEFAULT PRIVILEGES IN SCHEMA system_schema GRANT ALL ON TABLES TO itest_system_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA system_schema GRANT ALL ON SEQUENCES TO itest_system_user;
    ALTER DEFAULT PRIVILEGES IN SCHEMA system_schema GRANT ALL ON FUNCTIONS TO itest_system_user;
  END IF;

  -- 2. itest_plugins_user: SELECT / USAGE permissions on system_schema for plugin registry lookups
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_plugins_user;
    GRANT SELECT ON ALL TABLES IN SCHEMA system_schema TO itest_plugins_user;

    ALTER DEFAULT PRIVILEGES IN SCHEMA system_schema GRANT SELECT ON TABLES TO itest_plugins_user;
  END IF;
END $$;
