-- ==============================================================================
-- MIGRATION: 001_create_network_servers_table.sql
-- Module: lorawan-chirpstack
-- Schema: lorawan_chirpstack
-- Target: network_servers
-- Description: Creates isolated schema lorawan_chirpstack and table network_servers
--              with audit timestamps, trigger for updated_at, indices, and metadata.
-- ==============================================================================

-- 1. Ensure Schema exists
CREATE SCHEMA IF NOT EXISTS lorawan_chirpstack;

-- 2. Ensure Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 3. Dedicated Migration Versioning Table for Schema `lorawan_chirpstack`
CREATE TABLE IF NOT EXISTS lorawan_chirpstack."_migrations" (
  "id" SERIAL PRIMARY KEY,
  "migration_name" VARCHAR(255) NOT NULL UNIQUE,
  "batch" INTEGER NOT NULL DEFAULT 1,
  "applied_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "checksum" VARCHAR(64)
);

-- 4. Automatic updated_at Trigger Function
CREATE OR REPLACE FUNCTION lorawan_chirpstack.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Network Servers Table
-- Contract compatibility:
-- - id: UUID (PK)
-- - name: VARCHAR(100) (NOT NULL)
-- - api_url: VARCHAR(255) (NOT NULL)
-- - api_token: TEXT (NOT NULL)
-- - tenant_id: VARCHAR(100) (NULLABLE - optional ChirpStack v4 tenant reference)
-- - is_active: BOOLEAN (DEFAULT true)
-- - created_at: TIMESTAMPTZ (DEFAULT NOW())
-- - updated_at: TIMESTAMPTZ (DEFAULT NOW())
CREATE TABLE IF NOT EXISTS lorawan_chirpstack."network_servers" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "name" VARCHAR(100) NOT NULL,
  "api_url" VARCHAR(255) NOT NULL,
  "api_token" TEXT NOT NULL,
  "tenant_id" VARCHAR(100),
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "UQ_lorawan_chirpstack_network_servers_name" UNIQUE ("name")
);

-- 6. Indices for Performance
CREATE INDEX IF NOT EXISTS "idx_lorawan_cs_network_servers_is_active"
  ON lorawan_chirpstack."network_servers" ("is_active");

CREATE INDEX IF NOT EXISTS "idx_lorawan_cs_network_servers_tenant_id"
  ON lorawan_chirpstack."network_servers" ("tenant_id");

-- 7. Trigger for updated_at Auto-update
DROP TRIGGER IF EXISTS "trg_lorawan_cs_network_servers_updated_at" ON lorawan_chirpstack."network_servers";
CREATE TRIGGER "trg_lorawan_cs_network_servers_updated_at"
  BEFORE UPDATE ON lorawan_chirpstack."network_servers"
  FOR EACH ROW
  EXECUTE FUNCTION lorawan_chirpstack.set_current_timestamp_updated_at();

-- 8. Comments for Schema Documentation & Mirage/Upgrade Tooling
COMMENT ON SCHEMA lorawan_chirpstack IS 'Dedicated schema for ChirpStack LoRaWAN integration plugin';
COMMENT ON TABLE lorawan_chirpstack."network_servers" IS 'ChirpStack LoRaWAN Network Server connection profiles and credentials';
COMMENT ON COLUMN lorawan_chirpstack."network_servers"."id" IS 'Unique identifier (UUID)';
COMMENT ON COLUMN lorawan_chirpstack."network_servers"."name" IS 'Display name of ChirpStack network server';
COMMENT ON COLUMN lorawan_chirpstack."network_servers"."api_url" IS 'ChirpStack REST / gRPC API Base URL (e.g., http://localhost:8080)';
COMMENT ON COLUMN lorawan_chirpstack."network_servers"."api_token" IS 'ChirpStack API Secret Key / JWT Token for authentication';
COMMENT ON COLUMN lorawan_chirpstack."network_servers"."tenant_id" IS 'Optional ChirpStack v4 Tenant ID';
COMMENT ON COLUMN lorawan_chirpstack."network_servers"."is_active" IS 'Active status flag';
COMMENT ON COLUMN lorawan_chirpstack."network_servers"."created_at" IS 'Server profile creation timestamp';
COMMENT ON COLUMN lorawan_chirpstack."network_servers"."updated_at" IS 'Last update timestamp';

-- 9. Record Applied Migration in schema-level versioning table
INSERT INTO lorawan_chirpstack."_migrations" ("migration_name", "batch", "checksum")
VALUES ('001_create_network_servers_table.sql', 1, 'v1.0.0-lorawan-chirpstack')
ON CONFLICT ("migration_name") DO NOTHING;
