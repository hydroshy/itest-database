-- ==============================================================================
-- SCHEMA: finalconfig_manager
-- Module: finalconfig-manager
-- Description: Isolated schema for Final Config Profiles & Registers
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS finalconfig_manager;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS finalconfig_manager."_migrations" (
  "id" SERIAL PRIMARY KEY,
  "migration_name" VARCHAR(255) NOT NULL UNIQUE,
  "batch" INTEGER NOT NULL DEFAULT 1,
  "applied_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "checksum" VARCHAR(64)
);

CREATE OR REPLACE FUNCTION finalconfig_manager.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS finalconfig_manager."finalconfig_profile" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "so_number" VARCHAR(50) NOT NULL,
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

DROP TRIGGER IF EXISTS trg_finalconfig_profile_updated_at ON finalconfig_manager."finalconfig_profile";
CREATE TRIGGER trg_finalconfig_profile_updated_at
BEFORE UPDATE ON finalconfig_manager."finalconfig_profile"
FOR EACH ROW
EXECUTE FUNCTION finalconfig_manager.set_current_timestamp_updated_at();

CREATE TABLE IF NOT EXISTS finalconfig_manager."finalconfig_regs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "profile_id" UUID NOT NULL REFERENCES finalconfig_manager."finalconfig_profile"("id") ON DELETE CASCADE,
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

CREATE INDEX IF NOT EXISTS "idx_finalconfig_profile_sku_fw"
  ON finalconfig_manager."finalconfig_profile" ("sku", "long_fw");

CREATE INDEX IF NOT EXISTS "idx_finalconfig_profile_so"
  ON finalconfig_manager."finalconfig_profile" ("so_number");

CREATE INDEX IF NOT EXISTS "idx_finalconfig_profile_created_at"
  ON finalconfig_manager."finalconfig_profile" ("created_at" DESC);

CREATE INDEX IF NOT EXISTS "idx_finalconfig_regs_profile_id"
  ON finalconfig_manager."finalconfig_regs" ("profile_id");

CREATE INDEX IF NOT EXISTS "idx_finalconfig_regs_profile_dec"
  ON finalconfig_manager."finalconfig_regs" ("profile_id", "modbus_register_dec");

GRANT USAGE ON SCHEMA finalconfig_manager TO itest_system_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA finalconfig_manager TO itest_system_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA finalconfig_manager TO itest_system_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA finalconfig_manager TO itest_system_user;

GRANT USAGE ON SCHEMA finalconfig_manager TO itest_plugin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA finalconfig_manager TO itest_plugin_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA finalconfig_manager TO itest_plugin_user;
