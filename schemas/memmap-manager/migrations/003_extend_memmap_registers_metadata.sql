-- ==============================================================================
-- MIGRATION: 003_extend_memmap_registers_metadata.sql
-- Module: memmap-manager
-- Schema: memmap_manager
-- Description: Extends memmap_manager.memmap_registers table with metadata fields:
--              description, offset, default_value, and raw_register (JSONB).
--              Idempotent and safe for volume upgrades.
-- ==============================================================================

DO $$
BEGIN
  -- 1. description column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' 
      AND table_name = 'memmap_registers' 
      AND column_name = 'description'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "description" TEXT;
  END IF;

  -- 2. offset column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' 
      AND table_name = 'memmap_registers' 
      AND column_name = 'offset'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "offset" NUMERIC DEFAULT 0;
  END IF;

  -- 3. default_value column
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' 
      AND table_name = 'memmap_registers' 
      AND column_name = 'default_value'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "default_value" VARCHAR(255);
  END IF;

  -- 4. raw_register column (JSONB for legacy CSV raw fields & templates)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' 
      AND table_name = 'memmap_registers' 
      AND column_name = 'raw_register'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "raw_register" JSONB DEFAULT '{}';
  END IF;
END $$;
