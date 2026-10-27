-- ==============================================================================
-- MIGRATION: 002_add_name_column_to_decoder_scripts.sql
-- Description: Add name column to decoder.decoder_scripts and plugins_schema compatibility.
--              Includes backfilling from sku and long_fw, sync trigger, index,
--              refreshing views (v_memmap_decoders & plugins_schema.decoder_scripts),
--              and runtime role grants.
-- Schema: decoder
-- Idempotency: Safe to re-run on existing PostgreSQL databases.
-- ==============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'decoder' AND table_name = 'decoder_scripts'
    ) THEN
        -- 1. Add name column if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'decoder' AND table_name = 'decoder_scripts' AND column_name = 'name'
        ) THEN
            ALTER TABLE decoder.decoder_scripts ADD COLUMN name VARCHAR(255);
        END IF;

        -- 2. Backfill existing records
        UPDATE decoder.decoder_scripts
        SET name = COALESCE(NULLIF(TRIM(sku), ''), 'DECODER') || ' - ' || COALESCE(NULLIF(TRIM(long_fw), ''), 'DEFAULT')
        WHERE name IS NULL OR TRIM(name) = '';
    END IF;
END $$;

-- 3. Trigger for automatic name generation if not provided
CREATE OR REPLACE FUNCTION decoder.sync_decoder_script_name()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.name IS NULL OR TRIM(NEW.name) = '' THEN
        NEW.name = COALESCE(NULLIF(TRIM(NEW.sku), ''), 'DECODER') || ' - ' || COALESCE(NULLIF(TRIM(NEW.long_fw), ''), 'DEFAULT');
    END IF;
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_decoder_script_name ON decoder.decoder_scripts;
CREATE TRIGGER trg_sync_decoder_script_name
BEFORE INSERT OR UPDATE ON decoder.decoder_scripts
FOR EACH ROW
EXECUTE FUNCTION decoder.sync_decoder_script_name();

-- 4. Index on name
CREATE INDEX IF NOT EXISTS idx_decoder_name ON decoder.decoder_scripts(name);

-- 5. Refresh decoder.v_memmap_decoders view
DROP VIEW IF EXISTS decoder.v_memmap_decoders CASCADE;
CREATE OR REPLACE VIEW decoder.v_memmap_decoders AS
SELECT
    COALESCE(p.sku, d.sku) AS sku,
    COALESCE(p.long_fw, d.long_fw) AS long_fw,
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
    ON p.sku = d.sku AND p.long_fw = d.long_fw;

-- 6. Refresh plugins_schema compatibility views if plugins_schema exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'plugins_schema') THEN
        DROP VIEW IF EXISTS plugins_schema.v_memmap_decoders CASCADE;
        DROP VIEW IF EXISTS plugins_schema.decoder_scripts CASCADE;

        CREATE VIEW plugins_schema.decoder_scripts AS SELECT * FROM decoder.decoder_scripts;
        CREATE VIEW plugins_schema.v_memmap_decoders AS SELECT * FROM decoder.v_memmap_decoders;

        GRANT SELECT, INSERT, UPDATE, DELETE ON plugins_schema.decoder_scripts TO itest_system_user, itest_plugins_user;
        GRANT SELECT ON plugins_schema.decoder_scripts TO itest_ops_user;
        GRANT SELECT ON plugins_schema.v_memmap_decoders TO itest_system_user, itest_plugins_user, itest_ops_user;
    END IF;
END $$;

-- 7. Grant Permissions to Runtime Roles
GRANT USAGE ON SCHEMA decoder TO itest_system_user, itest_plugins_user, itest_ops_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE decoder.decoder_scripts TO itest_system_user, itest_plugins_user;
GRANT SELECT ON TABLE decoder.decoder_scripts TO itest_ops_user;
GRANT SELECT ON decoder.v_memmap_decoders TO itest_system_user, itest_plugins_user, itest_ops_user;
