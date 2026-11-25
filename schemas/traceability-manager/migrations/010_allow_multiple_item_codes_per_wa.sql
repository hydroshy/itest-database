-- ==============================================================================
-- MIGRATION: 010_allow_multiple_item_codes_per_wa.sql
-- Module: traceability-manager
-- Schema: traceability_manager
-- Description: Allow multiple distinct ITEM_CODE entries under the same Work
--              Authorization (WA) for a Sales Order (SO).
--              1. Drops the global single-column UNIQUE constraint on wa_number
--                 if present (traceability_wa_wa_number_key).
--              2. Ensures non-unique indexes on wa_number and item_code exist.
--              3. Creates composite UNIQUE index uq_traceability_wa_so_wa_item
--                 on (so_id, wa_number, COALESCE(item_code, '')) so each item line
--                 within a WA is uniquely tracked with its planned quantity.
-- ==============================================================================

DO $$
BEGIN
  -- 1. Drop existing unique constraint on wa_number if it exists
  IF EXISTS (
    SELECT 1
    FROM information_schema.table_constraints
    WHERE table_schema = 'traceability_manager'
      AND table_name = 'traceability_wa'
      AND constraint_name = 'traceability_wa_wa_number_key'
  ) THEN
    ALTER TABLE traceability_manager."traceability_wa" DROP CONSTRAINT "traceability_wa_wa_number_key";
  END IF;

  -- Drop unique index on wa_number if created as unique index directly
  IF EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'traceability_manager'
      AND tablename = 'traceability_wa'
      AND indexname = 'idx_traceability_wa_number_unique'
  ) THEN
    DROP INDEX traceability_manager.idx_traceability_wa_number_unique;
  END IF;
END $$;

-- 2. Ensure standard non-unique indexes exist for efficient queries
CREATE INDEX IF NOT EXISTS idx_traceability_wa_number
  ON traceability_manager."traceability_wa" ("wa_number");

CREATE INDEX IF NOT EXISTS idx_traceability_wa_item_code
  ON traceability_manager."traceability_wa" ("item_code");

-- 3. Composite unique index: (so_id, wa_number, COALESCE(item_code, ''))
-- Ensures each product item code within a WA is tracked as its own record without collision
CREATE UNIQUE INDEX IF NOT EXISTS uq_traceability_wa_so_wa_item
  ON traceability_manager."traceability_wa" ("so_id", "wa_number", COALESCE("item_code", ''));

-- 4. Ensure permissions granted to runtime system user
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE traceability_manager."traceability_wa" TO itest_system_user;
