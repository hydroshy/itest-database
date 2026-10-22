-- ==============================================================================
-- MIGRATION: 004_align_memmap_profiles_and_registers_to_human_spec.sql
-- Module: memmap-manager
-- Schema: memmap_manager
-- Description: Align memmap_profiles and memmap_registers schema to match human specification:
--   - memmap_profiles: sku, long_fw, short_fw, dec_check, hex_check, date_create, created_by
--   - memmap_registers: no, modbus_register_dec, modbus_register_hex, fc_read, fc_write,
--     num_registers, description, range, end_user_default, format, downlink_5,
--     in_rd1_template, comment, in_engineering_template, in_end_user_template,
--     in_full_template, val_dec_ok, val_hex_ok
-- Idempotent and safe for volume upgrades.
-- ==============================================================================

DO $$
BEGIN
  -- ============================================================================
  -- 1. EXTEND memmap_profiles
  -- ============================================================================

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_profiles' AND column_name = 'sku'
  ) THEN
    ALTER TABLE memmap_manager."memmap_profiles" ADD COLUMN "sku" VARCHAR(100);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_profiles' AND column_name = 'long_fw'
  ) THEN
    ALTER TABLE memmap_manager."memmap_profiles" ADD COLUMN "long_fw" VARCHAR(100);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_profiles' AND column_name = 'short_fw'
  ) THEN
    ALTER TABLE memmap_manager."memmap_profiles" ADD COLUMN "short_fw" VARCHAR(100);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_profiles' AND column_name = 'dec_check'
  ) THEN
    ALTER TABLE memmap_manager."memmap_profiles" ADD COLUMN "dec_check" BOOLEAN DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_profiles' AND column_name = 'hex_check'
  ) THEN
    ALTER TABLE memmap_manager."memmap_profiles" ADD COLUMN "hex_check" BOOLEAN DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_profiles' AND column_name = 'date_create'
  ) THEN
    ALTER TABLE memmap_manager."memmap_profiles" ADD COLUMN "date_create" TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_profiles' AND column_name = 'created_by'
  ) THEN
    ALTER TABLE memmap_manager."memmap_profiles" ADD COLUMN "created_by" VARCHAR(100);
  END IF;

  -- ============================================================================
  -- 2. EXTEND memmap_registers
  -- ============================================================================

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'no'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "no" INTEGER;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'modbus_register_dec'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "modbus_register_dec" INTEGER;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'modbus_register_hex'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "modbus_register_hex" VARCHAR(50);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'fc_read'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "fc_read" VARCHAR(50);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'fc_write'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "fc_write" VARCHAR(50);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'num_registers'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "num_registers" INTEGER DEFAULT 1;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'range'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "range" TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'end_user_default'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "end_user_default" VARCHAR(255);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'format'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "format" VARCHAR(50);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'downlink_5'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "downlink_5" TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'in_rd1_template'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "in_rd1_template" VARCHAR(50);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'comment'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "comment" TEXT;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'in_engineering_template'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "in_engineering_template" VARCHAR(50);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'in_end_user_template'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "in_end_user_template" VARCHAR(50);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'in_full_template'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "in_full_template" VARCHAR(50);
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'val_dec_ok'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "val_dec_ok" BOOLEAN DEFAULT true;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_registers' AND column_name = 'val_hex_ok'
  ) THEN
    ALTER TABLE memmap_manager."memmap_registers" ADD COLUMN "val_hex_ok" BOOLEAN DEFAULT true;
  END IF;

  -- Backfill existing rows if needed
  UPDATE memmap_manager."memmap_profiles"
  SET "date_create" = "created_at"
  WHERE "date_create" IS NULL;

  UPDATE memmap_manager."memmap_registers"
  SET "modbus_register_dec" = "address"
  WHERE "modbus_register_dec" IS NULL;

  UPDATE memmap_manager."memmap_registers"
  SET "end_user_default" = "default_value"
  WHERE "end_user_default" IS NULL AND "default_value" IS NOT NULL;

  UPDATE memmap_manager."memmap_registers"
  SET "format" = "data_type"
  WHERE "format" IS NULL AND "data_type" IS NOT NULL;

END $$;

-- Indices for performance
CREATE INDEX IF NOT EXISTS "idx_memmap_profiles_sku"
  ON memmap_manager."memmap_profiles" ("sku");

CREATE INDEX IF NOT EXISTS "idx_memmap_registers_modbus_dec"
  ON memmap_manager."memmap_registers" ("profile_id", "modbus_register_dec");

-- Permissions for runtime users
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA memmap_manager TO itest_system_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA memmap_manager TO itest_system_user;
GRANT SELECT ON ALL TABLES IN SCHEMA memmap_manager TO itest_plugin_user;
