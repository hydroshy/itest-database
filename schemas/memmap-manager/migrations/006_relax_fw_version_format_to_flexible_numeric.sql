-- ==============================================================================
-- MIGRATION: 006_relax_fw_version_format_to_flexible_numeric.sql
-- Description: Relax fw_version constraint in memmap_manager.memmap_profiles to
--              support XXFXXXX with XX as flexible numeric digits (1 to 32 digits, regex ^[0-9]+F[0-9]+$).
-- Schema: memmap_manager
-- Idempotency: Safe to re-run on existing PostgreSQL databases.
-- ==============================================================================

SET search_path TO memmap_manager, public;

-- 1. Drop compatibility views before altering column length to avoid PostgreSQL dependency errors
DROP VIEW IF EXISTS plugins_schema.v_memmap_profiles CASCADE;
DROP VIEW IF EXISTS memmap_manager.v_memmap_profiles CASCADE;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'memmap_manager' AND table_name = 'memmap_profiles'
  ) THEN
    -- 2. Expand column length to VARCHAR(100) to support flexible numeric prefixes
    ALTER TABLE memmap_manager."memmap_profiles"
      ALTER COLUMN "fw_version" TYPE VARCHAR(100);

    -- 3. Drop existing restrictive CHECK constraint if present
    ALTER TABLE memmap_manager."memmap_profiles"
      DROP CONSTRAINT IF EXISTS "chk_memmap_profiles_fw_version";

    -- 4. Add updated flexible CHECK constraint (XXFXXXX: digits before and after 'F')
    ALTER TABLE memmap_manager."memmap_profiles"
      ADD CONSTRAINT "chk_memmap_profiles_fw_version"
      CHECK ("fw_version" IS NULL OR "fw_version" ~ '^[0-9]+F[0-9]+$');
  END IF;
END $$;

COMMENT ON COLUMN memmap_manager."memmap_profiles"."fw_version" IS 'Phiên bản Firmware theo định dạng XXFXXXX với X là số (ví dụ: 4F0505, 12F0505, tối đa 32 chữ số)';

-- 5. Recreate views
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

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON TABLE memmap_manager."memmap_profiles" TO itest_ops_user;
    GRANT SELECT ON memmap_manager.v_memmap_profiles TO itest_ops_user;
    GRANT SELECT ON plugins_schema.v_memmap_profiles TO itest_ops_user;
  END IF;
END $$;
