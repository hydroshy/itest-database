-- ==============================================================================
-- MIGRATION: 005_add_operator_to_finalconfig_execution_session.sql
-- Description: Adds operator column to finalconfig_manager.finalconfig_execution_session
--              to track who performed the final configuration.
-- Module: finalconfig-manager / final-config
-- Schema: finalconfig_manager
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO finalconfig_manager, public;

-- 1. Add operator column to finalconfig_execution_session
ALTER TABLE finalconfig_manager."finalconfig_execution_session"
  ADD COLUMN IF NOT EXISTS "operator" VARCHAR(100);

COMMENT ON COLUMN finalconfig_manager."finalconfig_execution_session"."operator"
  IS 'Username hoặc họ tên của kỹ thuật viên / người thực hiện phiên Final Config';

-- 2. Backfill operator from metadata if available
UPDATE finalconfig_manager."finalconfig_execution_session"
SET "operator" = COALESCE(metadata->>'operator', metadata->>'configured_by', metadata->>'user')
WHERE "operator" IS NULL AND (metadata->>'operator' IS NOT NULL OR metadata->>'configured_by' IS NOT NULL OR metadata->>'user' IS NOT NULL);

-- 3. Create index for operator search
CREATE INDEX IF NOT EXISTS "idx_finalconfig_exec_session_operator"
  ON finalconfig_manager."finalconfig_execution_session" ("operator");

-- 4. Grant runtime privileges
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT ALL PRIVILEGES ON TABLE finalconfig_manager."finalconfig_execution_session" TO itest_system_user;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT ALL PRIVILEGES ON TABLE finalconfig_manager."finalconfig_execution_session" TO itest_plugins_user;
  END IF;
END $$;
