-- ==============================================================================
-- MIGRATION: 006_relax_fw_version_format_to_flexible_numeric.sql
-- Description: Relax fw_version constraint in memmap_manager.memmap_profiles to
--              support XXFXXXX with XX as flexible numeric digits (1 to 32 digits, regex ^[0-9]+F[0-9]+$).
-- Schema: memmap_manager
-- Idempotency: Safe to re-run on existing PostgreSQL databases.
-- ==============================================================================

SET search_path TO memmap_manager, public;

-- 1. Drop all dependent views before altering column type to avoid PostgreSQL rule _RETURN dependency errors
DROP VIEW IF EXISTS plugins_schema.v_memmap_decoders CASCADE;
DROP VIEW IF EXISTS decoder.v_memmap_decoders CASCADE;
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

-- 5. Recreate views with updated VARCHAR(100) column
CREATE OR REPLACE VIEW memmap_manager.v_memmap_profiles AS
SELECT
    p.id,
    p.sku,
    p.item_code,
    p.fw_version,
    COALESCE(p.long_fw, p.fw_version) AS long_fw,
    p.short_fw,
    p.name,
    p.description,
    p.sensor_connectivity,
    p.status,
    p.is_standard,
    p.created_by,
    p.created_at,
    p.updated_at,
    COALESCE(
        (SELECT COUNT(*) FROM memmap_manager.memmap_registers r WHERE r.profile_id = p.id),
        0
    ) AS total_registers
FROM memmap_manager."memmap_profiles" p;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'plugins_schema') THEN
        CREATE OR REPLACE VIEW plugins_schema.v_memmap_profiles AS
        SELECT * FROM memmap_manager.v_memmap_profiles;
    END IF;
END $$;

-- 6. Recreate decoder views if decoder.decoder_scripts exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'decoder' AND table_name = 'decoder_scripts'
  ) THEN
    CREATE OR REPLACE VIEW decoder.v_memmap_decoders AS
    SELECT
        COALESCE(p.item_code, d.item_code, p.sku, d.sku) AS item_code,
        COALESCE(p.fw_version, d.fw_version, d.fw_code, p.long_fw, d.long_fw) AS fw_version,
        COALESCE(p.sku, d.sku) AS sku,
        COALESCE(p.long_fw, d.long_fw) AS long_fw,
        d.fw_code,
        p.id AS memmap_profile_id,
        p.name AS memmap_profile_name,
        p.short_fw AS memmap_short_fw,
        d.id AS decoder_id,
        d.name AS decoder_name,
        d.protocol,
        d.description AS decoder_description,
        d.input_format,
        d.sample_payload,
        d.sample_fport,
        d.sample_decoded,
        COALESCE(d.is_active, false) AS has_active_decoder,
        (d.id IS NOT NULL) AS is_configured,
        d.created_at AS decoder_created_at,
        d.updated_at AS decoder_updated_at
    FROM memmap_manager.memmap_profiles p
    FULL OUTER JOIN decoder.decoder_scripts d
        ON (
            (p.item_code IS NOT NULL AND d.item_code IS NOT NULL AND LOWER(p.item_code) = LOWER(d.item_code)
             AND LOWER(COALESCE(p.fw_version, p.long_fw)) = LOWER(COALESCE(d.fw_version, d.fw_code, d.long_fw)))
            OR
            (p.sku IS NOT NULL AND d.sku IS NOT NULL AND LOWER(p.sku) = LOWER(d.sku)
             AND LOWER(p.long_fw) = LOWER(d.long_fw))
        );

    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'plugins_schema') THEN
      CREATE OR REPLACE VIEW plugins_schema.v_memmap_decoders AS
      SELECT * FROM decoder.v_memmap_decoders;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
      GRANT SELECT ON decoder.v_memmap_decoders TO itest_system_user;
      IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'plugins_schema' AND table_name = 'v_memmap_decoders') THEN
        GRANT SELECT ON plugins_schema.v_memmap_decoders TO itest_system_user;
      END IF;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
      GRANT SELECT ON decoder.v_memmap_decoders TO itest_plugins_user;
      IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'plugins_schema' AND table_name = 'v_memmap_decoders') THEN
        GRANT SELECT ON plugins_schema.v_memmap_decoders TO itest_plugins_user;
      END IF;
    END IF;
  END IF;
END $$;

-- 7. Permissions and grants
DO $$
BEGIN
    IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
        GRANT SELECT ON memmap_manager.v_memmap_profiles TO itest_system_user;
        IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'plugins_schema' AND table_name = 'v_memmap_profiles') THEN
            GRANT SELECT ON plugins_schema.v_memmap_profiles TO itest_system_user;
        END IF;
    END IF;

    IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
        GRANT SELECT ON memmap_manager.v_memmap_profiles TO itest_plugins_user;
        IF EXISTS (SELECT 1 FROM information_schema.views WHERE table_schema = 'plugins_schema' AND table_name = 'v_memmap_profiles') THEN
            GRANT SELECT ON plugins_schema.v_memmap_profiles TO itest_plugins_user;
        END IF;
    END IF;
END $$;
