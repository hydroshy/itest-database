-- ==============================================================================
-- MIGRATION: 005_identify_by_item_code_and_fw_version.sql
-- Module: memmap-manager / memmap-payload
-- Schema: memmap_manager
-- Target: memmap_profiles, v_memmap_profiles
-- Description:
--   1. Add item_code and fw_version columns to memmap_manager.memmap_profiles.
--   2. Switch identification of memmap profiles to (item_code, fw_version) instead of SKU.
--   3. Add validation CHECK constraint on fw_version matching regex ^[0-9]F[0-9]{4}$ (format XFXXXX with X as digits).
--   4. Add unique index for (item_code, fw_version) and lookup indexes.
--   5. Create/refresh views: memmap_manager.v_memmap_profiles and plugins_schema.v_memmap_profiles.
--   6. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

DO $$
BEGIN
  -- 1. Add item_code to memmap_profiles
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_profiles' AND column_name = 'item_code'
  ) THEN
    ALTER TABLE memmap_manager."memmap_profiles" ADD COLUMN "item_code" VARCHAR(100);
  END IF;

  -- 2. Add fw_version to memmap_profiles
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_profiles' AND column_name = 'fw_version'
  ) THEN
    ALTER TABLE memmap_manager."memmap_profiles" ADD COLUMN "fw_version" VARCHAR(50);
  END IF;

  -- 3. Add CHECK constraint for fw_version format (XFXXXX with X as digits)
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'chk_memmap_profiles_fw_version'
      AND conrelid = 'memmap_manager.memmap_profiles'::regclass
  ) THEN
    ALTER TABLE memmap_manager."memmap_profiles"
      ADD CONSTRAINT "chk_memmap_profiles_fw_version"
      CHECK ("fw_version" IS NULL OR "fw_version" ~ '^[0-9]F[0-9]{4}$');
  END IF;
END $$;

COMMENT ON COLUMN memmap_manager."memmap_profiles"."item_code" IS 'Mã ITEM_CODE định danh thiết bị của profile memmap (thay thế SKU)';
COMMENT ON COLUMN memmap_manager."memmap_profiles"."fw_version" IS 'Phiên bản Firmware theo định dạng XFXXXX với X là số (ví dụ: 1F0001, 0F0000)';

-- 4. Unique and search indexes
CREATE UNIQUE INDEX IF NOT EXISTS "idx_memmap_profiles_item_code_fw_version"
  ON memmap_manager."memmap_profiles" ("item_code", "fw_version")
  WHERE "item_code" IS NOT NULL AND "fw_version" IS NOT NULL;

CREATE INDEX IF NOT EXISTS "idx_memmap_profiles_item_code"
  ON memmap_manager."memmap_profiles" ("item_code");

CREATE INDEX IF NOT EXISTS "idx_memmap_profiles_fw_version"
  ON memmap_manager."memmap_profiles" ("fw_version");

-- 5. Views
DROP VIEW IF EXISTS plugins_schema.v_memmap_profiles CASCADE;
DROP VIEW IF EXISTS memmap_manager.v_memmap_profiles CASCADE;
CREATE OR REPLACE VIEW memmap_manager.v_memmap_profiles AS
SELECT
  p."id",
  p."name",
  p."item_code",
  p."fw_version",
  p."sku",
  p."long_fw",
  p."short_fw",
  COALESCE(p."dec_check", true) AS "dec_check",
  COALESCE(p."hex_check", true) AS "hex_check",
  p."created_by",
  p."date_create",
  p."description",
  p."source_format",
  p."created_at",
  p."updated_at",
  COALESCE(
    (SELECT COUNT(*)::int FROM memmap_manager."memmap_registers" r WHERE r."profile_id" = p."id"),
    0
  ) AS "registers_count"
FROM memmap_manager."memmap_profiles" p;

COMMENT ON VIEW memmap_manager.v_memmap_profiles IS 'View danh sách memmap profiles kèm item_code, fw_version và số lượng registers';

CREATE OR REPLACE VIEW plugins_schema.v_memmap_profiles AS
SELECT * FROM memmap_manager.v_memmap_profiles;

-- 6. Runtime Privilege Grants
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT ALL PRIVILEGES ON TABLE memmap_manager."memmap_profiles" TO itest_system_user;
    GRANT SELECT ON memmap_manager.v_memmap_profiles TO itest_system_user;
    GRANT SELECT ON plugins_schema.v_memmap_profiles TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT ALL PRIVILEGES ON TABLE memmap_manager."memmap_profiles" TO itest_plugins_user;
    GRANT SELECT ON memmap_manager.v_memmap_profiles TO itest_plugins_user;
    GRANT SELECT ON plugins_schema.v_memmap_profiles TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT ALL PRIVILEGES ON TABLE memmap_manager."memmap_profiles" TO itest_plugin_user;
    GRANT SELECT ON memmap_manager.v_memmap_profiles TO itest_plugin_user;
    GRANT SELECT ON plugins_schema.v_memmap_profiles TO itest_plugin_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON TABLE memmap_manager."memmap_profiles" TO itest_ops_user;
    GRANT SELECT ON memmap_manager.v_memmap_profiles TO itest_ops_user;
    GRANT SELECT ON plugins_schema.v_memmap_profiles TO itest_ops_user;
  END IF;
END $$;
