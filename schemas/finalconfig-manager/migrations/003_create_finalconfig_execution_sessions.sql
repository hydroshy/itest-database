-- ==============================================================================
-- MIGRATION: 003_create_finalconfig_execution_sessions.sql
-- Module: finalconfig-manager
-- Schema: finalconfig_manager
-- Description: Creates finalconfig_execution_session and finalconfig_execution_log
--              tables for stateful execution session management and step checkpoints.
-- ==============================================================================

-- 1. Execution Sessions Table
-- Tracks stateful execution across register reads/writes for a profile/device
CREATE TABLE IF NOT EXISTS finalconfig_manager."finalconfig_execution_session" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "profile_id" UUID NOT NULL REFERENCES finalconfig_manager."finalconfig_profile"("id") ON DELETE CASCADE,
  "device_id" VARCHAR(100),
  "serial_number" VARCHAR(100),
  "status" VARCHAR(30) NOT NULL DEFAULT 'IN_PROGRESS', -- 'IN_PROGRESS', 'PAUSED', 'COMPLETED', 'FAILED', 'ABORTED'
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

-- 2. Trigger for updated_at on execution session
DROP TRIGGER IF EXISTS trg_finalconfig_execution_session_updated_at ON finalconfig_manager."finalconfig_execution_session";
CREATE TRIGGER trg_finalconfig_execution_session_updated_at
BEFORE UPDATE ON finalconfig_manager."finalconfig_execution_session"
FOR EACH ROW
EXECUTE FUNCTION finalconfig_manager.set_current_timestamp_updated_at();

-- 3. Execution Logs Table (Step Checkpoint)
-- Records read/write results per register for audit and recovery
CREATE TABLE IF NOT EXISTS finalconfig_manager."finalconfig_execution_log" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "session_id" UUID NOT NULL REFERENCES finalconfig_manager."finalconfig_execution_session"("id") ON DELETE CASCADE,
  "modbus_register_dec" INTEGER NOT NULL,
  "modbus_register_hex" VARCHAR(20),
  "action" VARCHAR(20) NOT NULL DEFAULT 'WRITE', -- 'READ', 'WRITE', 'VERIFY'
  "expected_value" TEXT,
  "written_value" TEXT,
  "read_value" TEXT,
  "raw_hex" VARCHAR(255),
  "status" VARCHAR(20) NOT NULL DEFAULT 'PASS', -- 'PASS', 'FAIL', 'SKIPPED'
  "error_message" TEXT,
  "duration_ms" INTEGER DEFAULT 0,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 4. Indexes for Query Performance & Lookups
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

-- 5. Grant Permissions to Runtime Roles (Idempotent)
GRANT SELECT, INSERT, UPDATE, DELETE ON finalconfig_manager."finalconfig_execution_session" TO itest_system_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON finalconfig_manager."finalconfig_execution_log" TO itest_system_user;

GRANT SELECT, INSERT, UPDATE, DELETE ON finalconfig_manager."finalconfig_execution_session" TO itest_plugin_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON finalconfig_manager."finalconfig_execution_log" TO itest_plugin_user;
