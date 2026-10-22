-- ==============================================================================
-- MIGRATION: 001_create_memmap_manager_tables.sql
-- Module: memmap-manager
-- Schema: memmap_manager
-- Description: Creates isolated schema memmap_manager and tables memmap_profiles,
--              memmap_registers with audit timestamps, triggers, and indices.
-- ==============================================================================

-- 1. Ensure Schema exists
CREATE SCHEMA IF NOT EXISTS memmap_manager;

-- 2. Ensure Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 3. Dedicated Migration Versioning Table for Schema `memmap_manager`
CREATE TABLE IF NOT EXISTS memmap_manager."_migrations" (
  "id" SERIAL PRIMARY KEY,
  "migration_name" VARCHAR(255) NOT NULL UNIQUE,
  "batch" INTEGER NOT NULL DEFAULT 1,
  "applied_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "checksum" VARCHAR(64)
);

-- 4. Automatic updated_at Trigger Function
CREATE OR REPLACE FUNCTION memmap_manager.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. MemMap Profiles Table
-- Contract:
-- - id: UUID (PK)
-- - name: VARCHAR(100) (NOT NULL)
-- - description: TEXT
-- - source_format: VARCHAR(20) (NOT NULL, e.g. 'json', 'csv', 'excel')
-- - created_at: TIMESTAMPTZ (DEFAULT NOW())
-- - updated_at: TIMESTAMPTZ (DEFAULT NOW())
CREATE TABLE IF NOT EXISTS memmap_manager."memmap_profiles" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "name" VARCHAR(100) NOT NULL,
  "description" TEXT,
  "source_format" VARCHAR(20) NOT NULL DEFAULT 'json',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indices for Profiles
CREATE INDEX IF NOT EXISTS "idx_memmap_profiles_name"
  ON memmap_manager."memmap_profiles" ("name");
CREATE INDEX IF NOT EXISTS "idx_memmap_profiles_created_at"
  ON memmap_manager."memmap_profiles" ("created_at" DESC);

-- Trigger for Profiles updated_at
DROP TRIGGER IF EXISTS "trg_memmap_profiles_updated_at" ON memmap_manager."memmap_profiles";
CREATE TRIGGER "trg_memmap_profiles_updated_at"
  BEFORE UPDATE ON memmap_manager."memmap_profiles"
  FOR EACH ROW
  EXECUTE FUNCTION memmap_manager.set_current_timestamp_updated_at();

-- 6. MemMap Registers Table
-- Contract:
-- - id: UUID (PK)
-- - profile_id: UUID (FK -> memmap_profiles.id ON DELETE CASCADE)
-- - name: VARCHAR(100) (NOT NULL)
-- - address: INTEGER (NOT NULL)
-- - data_type: VARCHAR(30) (NOT NULL, e.g. 'uint16', 'int16', 'float32', 'boolean')
-- - scale: NUMERIC DEFAULT 1
-- - unit: VARCHAR(30)
-- - access_mode: VARCHAR(20) DEFAULT 'RO' (e.g. 'RO', 'RW', 'WO')
-- - created_at: TIMESTAMPTZ (DEFAULT NOW())
CREATE TABLE IF NOT EXISTS memmap_manager."memmap_registers" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "profile_id" UUID NOT NULL REFERENCES memmap_manager."memmap_profiles"("id") ON DELETE CASCADE,
  "name" VARCHAR(100) NOT NULL,
  "address" INTEGER NOT NULL,
  "data_type" VARCHAR(30) NOT NULL DEFAULT 'uint16',
  "scale" NUMERIC DEFAULT 1,
  "unit" VARCHAR(30),
  "access_mode" VARCHAR(20) NOT NULL DEFAULT 'RO',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indices for Registers
CREATE INDEX IF NOT EXISTS "idx_memmap_registers_profile_id"
  ON memmap_manager."memmap_registers" ("profile_id");
CREATE INDEX IF NOT EXISTS "idx_memmap_registers_address"
  ON memmap_manager."memmap_registers" ("profile_id", "address");

-- Comments
COMMENT ON SCHEMA memmap_manager IS 'Isolated schema for MemMap Manager profiles, register definitions, and file import history.';
COMMENT ON TABLE memmap_manager."memmap_profiles" IS 'User-imported memory map profiles (modbus/memory layout configurations).';
COMMENT ON TABLE memmap_manager."memmap_registers" IS 'Individual register definitions associated with a MemMap profile.';
