-- ==============================================================================
-- ITEST PLATFORM - MULTI-SCHEMA INITIALIZATION SCRIPT (POSTGRESQL 17)
-- ==============================================================================
-- File: init-scripts/01-init-databases.sql
-- Description: Creates schemas, dedicated service users, and enforces least-privilege
--              access control for itest-system, itest-plugins, and itest-ops-agent.
-- ==============================================================================

-- 1. Enable Global Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. Create Isolated Schemas
CREATE SCHEMA IF NOT EXISTS system_schema;
CREATE SCHEMA IF NOT EXISTS plugins_schema;
CREATE SCHEMA IF NOT EXISTS ops_schema;

-- 3. Create Dedicated Service Roles / Users
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    CREATE ROLE itest_system_user WITH LOGIN PASSWORD 'system_secret_2026';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    CREATE ROLE itest_plugins_user WITH LOGIN PASSWORD 'plugins_secret_2026';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    CREATE ROLE itest_ops_user WITH LOGIN PASSWORD 'ops_secret_2026';
  END IF;
END $$;

-- 4. Grant Schema Usage & Privileges (Least Privilege Isolation)

-- Revoke default public schema create from public
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

-- SYSTEM USER: Full permissions on system_schema, read-only or no access to others
GRANT USAGE, CREATE ON SCHEMA system_schema TO itest_system_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA system_schema GRANT ALL ON TABLES TO itest_system_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA system_schema GRANT ALL ON SEQUENCES TO itest_system_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA system_schema GRANT ALL ON FUNCTIONS TO itest_system_user;

-- PLUGINS USER: Full permissions on plugins_schema, read permission on system_schema (for device/plugin lookups)
GRANT USAGE, CREATE ON SCHEMA plugins_schema TO itest_plugins_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA plugins_schema GRANT ALL ON TABLES TO itest_plugins_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA plugins_schema GRANT ALL ON SEQUENCES TO itest_plugins_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA plugins_schema GRANT ALL ON FUNCTIONS TO itest_plugins_user;

GRANT USAGE ON SCHEMA system_schema TO itest_plugins_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA system_schema GRANT SELECT ON TABLES TO itest_plugins_user;

-- OPS AGENT USER: Full permissions on ops_schema, read-only on system_schema & plugins_schema for telemetry / health monitoring
GRANT USAGE, CREATE ON SCHEMA ops_schema TO itest_ops_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA ops_schema GRANT ALL ON TABLES TO itest_ops_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA ops_schema GRANT ALL ON SEQUENCES TO itest_ops_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA ops_schema GRANT ALL ON FUNCTIONS TO itest_ops_user;

GRANT USAGE ON SCHEMA system_schema TO itest_ops_user;
GRANT USAGE ON SCHEMA plugins_schema TO itest_ops_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA system_schema GRANT SELECT ON TABLES TO itest_ops_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA plugins_schema GRANT SELECT ON TABLES TO itest_ops_user;

-- 5. Set default search_path for service roles
ALTER ROLE itest_system_user SET search_path TO system_schema, public;
ALTER ROLE itest_plugins_user SET search_path TO plugins_schema, system_schema, public;
ALTER ROLE itest_ops_user SET search_path TO ops_schema, system_schema, plugins_schema, public;

