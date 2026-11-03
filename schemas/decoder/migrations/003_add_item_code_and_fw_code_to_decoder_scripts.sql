-- ==============================================================================
-- MIGRATION: 003_add_item_code_and_fw_code_to_decoder_scripts.sql
-- Description: Add item_code and fw_code columns to decoder.decoder_scripts for
--              device testing mapping, indexes, view refreshes, and runtime role grants.
-- Schema: decoder
-- Idempotency: Safe to re-run on existing PostgreSQL databases.
-- ==============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'decoder' AND table_name = 'decoder_scripts'
    ) THEN
        -- 1. Add item_code column if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'decoder' AND table_name = 'decoder_scripts' AND column_name = 'item_code'
        ) THEN
            ALTER TABLE decoder.decoder_scripts ADD COLUMN item_code VARCHAR(100);
        END IF;

        -- 2. Add fw_code column if missing
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'decoder' AND table_name = 'decoder_scripts' AND column_name = 'fw_code'
        ) THEN
            ALTER TABLE decoder.decoder_scripts ADD COLUMN fw_code VARCHAR(50);
        END IF;
    END IF;
END $$;

-- 3. Indexes for fast testing device matching
CREATE INDEX IF NOT EXISTS idx_decoder_scripts_item_code ON decoder.decoder_scripts(item_code);
CREATE INDEX IF NOT EXISTS idx_decoder_scripts_fw_code ON decoder.decoder_scripts(fw_code);
CREATE INDEX IF NOT EXISTS idx_decoder_scripts_item_fw ON decoder.decoder_scripts(item_code, fw_code);

-- 4. Refresh decoder.v_memmap_decoders view
DROP VIEW IF EXISTS decoder.v_memmap_decoders CASCADE;
CREATE OR REPLACE VIEW decoder.v_memmap_decoders AS
SELECT
    COALESCE(p.sku, d.sku) AS sku,
    COALESCE(p.long_fw, d.long_fw) AS long_fw,
    d.item_code,
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
    ON p.sku = d.sku AND p.long_fw = d.long_fw;

-- 5. Refresh plugins_schema compatibility views if plugins_schema exists
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

-- 6. Grant Permissions to Runtime Roles
GRANT USAGE ON SCHEMA decoder TO itest_system_user, itest_plugins_user, itest_ops_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE decoder.decoder_scripts TO itest_system_user, itest_plugins_user;
GRANT SELECT ON TABLE decoder.decoder_scripts TO itest_ops_user;
GRANT SELECT ON decoder.v_memmap_decoders TO itest_system_user, itest_plugins_user, itest_ops_user;
