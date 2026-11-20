-- ==============================================================================
-- SCHEMA: preconfig_manager
-- Module: preconfig-manager
-- Description: Isolated schema for Preconfig Profiles & Registers
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS preconfig_manager;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS preconfig_manager."_migrations" (
  "id" SERIAL PRIMARY KEY,
  "migration_name" VARCHAR(255) NOT NULL UNIQUE,
  "batch" INTEGER NOT NULL DEFAULT 1,
  "applied_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "checksum" VARCHAR(64)
);

CREATE OR REPLACE FUNCTION preconfig_manager.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS preconfig_manager."preconfig_profile" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "so_number" VARCHAR(50) NOT NULL,
  "wa_number" VARCHAR(50),
  "item_code" VARCHAR(100) NOT NULL,
  "connectivity" VARCHAR(20) NOT NULL,
  "sku" VARCHAR(100) NOT NULL,
  "long_fw" VARCHAR(50) NOT NULL,
  "short_fw" VARCHAR(20) NOT NULL,
  "registers_count" INTEGER NOT NULL DEFAULT 0,
  "created_by" VARCHAR(100),
  "notes" TEXT,
  "status" VARCHAR(20) NOT NULL DEFAULT 'active',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE preconfig_manager."preconfig_profile"
  ADD COLUMN IF NOT EXISTS "wa_number" VARCHAR(50);

DROP TRIGGER IF EXISTS trg_preconfig_profile_updated_at ON preconfig_manager."preconfig_profile";
CREATE TRIGGER trg_preconfig_profile_updated_at
BEFORE UPDATE ON preconfig_manager."preconfig_profile"
FOR EACH ROW
EXECUTE FUNCTION preconfig_manager.set_current_timestamp_updated_at();

CREATE TABLE IF NOT EXISTS preconfig_manager."preconfig_regs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "profile_id" UUID NOT NULL REFERENCES preconfig_manager."preconfig_profile"("id") ON DELETE CASCADE,
  "row_number" INTEGER,
  "modbus_register_dec" INTEGER NOT NULL,
  "modbus_register_hex" VARCHAR(20) NOT NULL,
  "register_count" INTEGER NOT NULL DEFAULT 1,
  "description" TEXT NOT NULL,
  "format" VARCHAR(50),
  "comment" TEXT,
  "end_user_default" TEXT,
  "input_config" TEXT,
  "config_check" VARCHAR(20) NOT NULL DEFAULT 'PASS',
  "selected" BOOLEAN NOT NULL DEFAULT TRUE,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_preconfig_profile_sku_fw"
  ON preconfig_manager."preconfig_profile" ("sku", "long_fw");

CREATE INDEX IF NOT EXISTS "idx_preconfig_profile_so"
  ON preconfig_manager."preconfig_profile" ("so_number");

CREATE INDEX IF NOT EXISTS "idx_preconfig_profile_wa"
  ON preconfig_manager."preconfig_profile" ("wa_number");

CREATE INDEX IF NOT EXISTS "idx_preconfig_profile_lookup"
  ON preconfig_manager."preconfig_profile" ("so_number", "wa_number", "item_code");

CREATE INDEX IF NOT EXISTS "idx_preconfig_profile_created_at"
  ON preconfig_manager."preconfig_profile" ("created_at" DESC);

CREATE INDEX IF NOT EXISTS "idx_preconfig_regs_profile_id"
  ON preconfig_manager."preconfig_regs" ("profile_id");

CREATE INDEX IF NOT EXISTS "idx_preconfig_regs_profile_dec"
  ON preconfig_manager."preconfig_regs" ("profile_id", "modbus_register_dec");

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE ON SCHEMA preconfig_manager TO itest_system_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA preconfig_manager TO itest_system_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA preconfig_manager TO itest_system_user;
    GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA preconfig_manager TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE ON SCHEMA preconfig_manager TO itest_plugins_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA preconfig_manager TO itest_plugins_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA preconfig_manager TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT USAGE ON SCHEMA preconfig_manager TO itest_plugin_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA preconfig_manager TO itest_plugin_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA preconfig_manager TO itest_plugin_user;
  END IF;
END $$;
