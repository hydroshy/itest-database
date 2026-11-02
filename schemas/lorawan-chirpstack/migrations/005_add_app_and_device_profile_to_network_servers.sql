-- ==============================================================================
-- MIGRATION: 005_add_app_and_device_profile_to_network_servers.sql
-- Description:
--   1. Add application_id (VARCHAR 100) and device_profile_id (VARCHAR 100)
--      to lorawan_chirpstack.network_servers table for ChirpStack v4 multi-application
--      and device profile management under tenant.
--   2. Add indexes on application_id and device_profile_id.
--   3. Grant runtime privileges to itest_plugins_user, itest_system_user, and itest_ops_user.
-- Schema: lorawan_chirpstack, public
-- ==============================================================================

SET search_path TO lorawan_chirpstack, public;

-- 1. Alter table network_servers
ALTER TABLE lorawan_chirpstack."network_servers"
  ADD COLUMN IF NOT EXISTS "application_id" VARCHAR(100),
  ADD COLUMN IF NOT EXISTS "device_profile_id" VARCHAR(100);

COMMENT ON COLUMN lorawan_chirpstack."network_servers"."application_id" IS 'ChirpStack Application ID mặc định hoặc quản lý dưới Tenant';
COMMENT ON COLUMN lorawan_chirpstack."network_servers"."device_profile_id" IS 'ChirpStack Device Profile ID tương ứng với Tenant ID';

-- 2. Indexes for fast lookup
CREATE INDEX IF NOT EXISTS "idx_lorawan_cs_network_servers_app_id"
  ON lorawan_chirpstack."network_servers" ("application_id");

CREATE INDEX IF NOT EXISTS "idx_lorawan_cs_network_servers_dev_profile_id"
  ON lorawan_chirpstack."network_servers" ("device_profile_id");

CREATE INDEX IF NOT EXISTS "idx_lorawan_cs_network_servers_tenant_app"
  ON lorawan_chirpstack."network_servers" ("tenant_id", "application_id");

-- 3. Runtime Grants
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON lorawan_chirpstack."network_servers" TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON lorawan_chirpstack."network_servers" TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON lorawan_chirpstack."network_servers" TO itest_ops_user;
  END IF;
END $$;
