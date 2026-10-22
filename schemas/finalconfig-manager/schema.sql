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

-- 3. Execution Sessions Table
CREATE TABLE IF NOT EXISTS finalconfig_manager."finalconfig_execution_session" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "profile_id" UUID NOT NULL REFERENCES finalconfig_manager."finalconfig_profile"("id") ON DELETE CASCADE,
  "device_id" VARCHAR(100),
  "serial_number" VARCHAR(100),
  "status" VARCHAR(30) NOT NULL DEFAULT 'IN_PROGRESS',
  "current_step" INTEGER NOT NULL DEFAULT 0,
  "total_steps" INTEGER NOT NULL DEFAULT 0,
  "passed_steps" INTEGER NOT NULL DEFAULT 0,
  "failed_steps" INTEGER NOT NULL DEFAULT 0,
  "started_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "completed_at" TIMESTAMPTZ,
  "error_message" TEXT,
  "metadata" JSONB DEFAULT '{}'::jsonb,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

DROP TRIGGER IF EXISTS trg_finalconfig_execution_session_updated_at ON finalconfig_manager."finalconfig_execution_session";
CREATE TRIGGER trg_finalconfig_execution_session_updated_at
BEFORE UPDATE ON finalconfig_manager."finalconfig_execution_session"
FOR EACH ROW
EXECUTE FUNCTION finalconfig_manager.set_current_timestamp_updated_at();

-- 4. Execution Logs Table (Step Checkpoint)
CREATE TABLE IF NOT EXISTS finalconfig_manager."finalconfig_execution_log" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "session_id" UUID NOT NULL REFERENCES finalconfig_manager."finalconfig_execution_session"("id") ON DELETE CASCADE,
  "modbus_register_dec" INTEGER NOT NULL,
  "modbus_register_hex" VARCHAR(20),
  "action" VARCHAR(20) NOT NULL DEFAULT 'WRITE',
  "expected_value" TEXT,
  "written_value" TEXT,
  "read_value" TEXT,
  "raw_hex" VARCHAR(255),
  "status" VARCHAR(20) NOT NULL DEFAULT 'PASS',
  "error_message" TEXT,
  "duration_ms" INTEGER DEFAULT 0,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS "idx_finalconfig_exec_session_profile"
  ON finalconfig_manager."finalconfig_execution_session" ("profile_id");

CREATE INDEX IF NOT EXISTS "idx_finalconfig_exec_session_status"
  ON finalconfig_manager."finalconfig_execution_session" ("status");

CREATE INDEX IF NOT EXISTS "idx_finalconfig_exec_session_created"
  ON finalconfig_manager."finalconfig_execution_session" ("created_at" DESC);

CREATE INDEX IF NOT EXISTS "idx_finalconfig_exec_log_session"
  ON finalconfig_manager."finalconfig_execution_log" ("session_id");

CREATE INDEX IF NOT EXISTS "idx_finalconfig_exec_log_session_dec"
  ON finalconfig_manager."finalconfig_execution_log" ("session_id", "modbus_register_dec");

CREATE INDEX IF NOT EXISTS "idx_finalconfig_exec_log_created"
  ON finalconfig_manager."finalconfig_execution_log" ("created_at" DESC);

GRANT USAGE ON SCHEMA finalconfig_manager TO itest_system_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA finalconfig_manager TO itest_system_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA finalconfig_manager TO itest_system_user;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA finalconfig_manager TO itest_system_user;

GRANT USAGE ON SCHEMA finalconfig_manager TO itest_plugin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA finalconfig_manager TO itest_plugin_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA finalconfig_manager TO itest_plugin_user;
