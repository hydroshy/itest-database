-- ==============================================================================
-- MIGRATION: 002_grant_runtime_privileges.sql
-- Module: lorawan-chirpstack
-- Description: Repairs runtime grants for existing PostgreSQL volumes. Init scripts
-- only execute on first volume creation, so the grants below are deliberately
-- idempotent and apply to already-created schema objects as well.
-- ==============================================================================

GRANT USAGE ON SCHEMA lorawan_chirpstack TO itest_system_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lorawan_chirpstack TO itest_system_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA lorawan_chirpstack TO itest_system_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA lorawan_chirpstack TO itest_system_user;

-- Grants created by future ChirpStack migrations run by the database owner.
ALTER DEFAULT PRIVILEGES IN SCHEMA lorawan_chirpstack
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO itest_system_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA lorawan_chirpstack
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO itest_system_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA lorawan_chirpstack
  GRANT EXECUTE ON FUNCTIONS TO itest_system_user;
