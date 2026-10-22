-- ==============================================================================
-- MIGRATION: 002_grant_runtime_privileges.sql
-- Module: memmap-manager
-- Description: Runtime grants for existing and future PostgreSQL objects in
--              schema memmap_manager. Idempotent and safe for volume upgrades.
-- ==============================================================================

GRANT USAGE ON SCHEMA memmap_manager TO itest_system_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA memmap_manager TO itest_system_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA memmap_manager TO itest_system_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA memmap_manager TO itest_system_user;

-- Plugin user permissions (if plugins directly read profiles)
GRANT USAGE ON SCHEMA memmap_manager TO itest_plugin_user;
GRANT SELECT ON ALL TABLES IN SCHEMA memmap_manager TO itest_plugin_user;

-- Grants created by future migrations run by the database owner.
ALTER DEFAULT PRIVILEGES IN SCHEMA memmap_manager
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_system_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA memmap_manager
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_system_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA memmap_manager
  GRANT EXECUTE ON FUNCTIONS TO itest_system_user;

ALTER DEFAULT PRIVILEGES IN SCHEMA memmap_manager
  GRANT SELECT ON TABLES TO itest_plugin_user;
