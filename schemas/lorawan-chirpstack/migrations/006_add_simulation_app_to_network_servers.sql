-- ==============================================================================
-- MIGRATION: 006_add_simulation_app_to_network_servers.sql
-- Description:
--   1. Add simulation_application_id (VARCHAR 100) to lorawan_chirpstack.network_servers
--      table to manage two default Application IDs:
--        - application_id: Default Application for Testing Unit / Device Testing
--        - simulation_application_id: Default Application for Simulation Device
--   2. Add indexes on simulation_application_id and composite (tenant_id, simulation_application_id).
--   3. Grant runtime privileges to itest_plugins_user, itest_system_user, and itest_ops_user.
-- Schema: lorawan_chirpstack, public
-- Idempotency: Safe to re-run on existing PostgreSQL databases.
-- ==============================================================================

SET search_path TO lorawan_chirpstack, public;

-- 1. Alter table network_servers to add simulation_application_id
ALTER TABLE lorawan_chirpstack."network_servers"
  ADD COLUMN IF NOT EXISTS "simulation_application_id" VARCHAR(100);

COMMENT ON COLUMN lorawan_chirpstack."network_servers"."application_id" IS 'ChirpStack Application ID mặc định cho Testing Unit';
COMMENT ON COLUMN lorawan_chirpstack."network_servers"."simulation_application_id" IS 'ChirpStack Application ID mặc định cho Simulation Device';

-- 2. Indexes for fast lookup
CREATE INDEX IF NOT EXISTS "idx_lorawan_cs_network_servers_sim_app_id"
  ON lorawan_chirpstack."network_servers" ("simulation_application_id");

CREATE INDEX IF NOT EXISTS "idx_lorawan_cs_network_servers_tenant_sim_app"
  ON lorawan_chirpstack."network_servers" ("tenant_id", "simulation_application_id");

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
