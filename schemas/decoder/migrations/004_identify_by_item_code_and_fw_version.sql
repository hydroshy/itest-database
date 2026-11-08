-- ==============================================================================
-- MIGRATION: 004_identify_by_item_code_and_fw_version.sql
-- Description: Transition decoder_scripts primary identity from SKU/LONG_FW to
--              ITEM_CODE and FW_VERSION (format XFXXXX, regex ^[0-9]F[0-9]{4}$).
--              Make sku and long_fw nullable, add fw_version column, update
--              views and grant permissions.
-- Schema: decoder
-- Idempotency: Safe to re-run on existing PostgreSQL databases.
-- ==============================================================================

SET search_path TO decoder, public;

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

        -- 3. Add fw_version column if missing (synonym with fw_code for consistency with memmap_profiles)
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'decoder' AND table_name = 'decoder_scripts' AND column_name = 'fw_version'
        ) THEN
            ALTER TABLE decoder.decoder_scripts ADD COLUMN fw_version VARCHAR(50);
        END IF;

        -- 4. Allow sku and long_fw to be nullable (since item_code and fw_version are now primary)
        ALTER TABLE decoder.decoder_scripts ALTER COLUMN sku DROP NOT NULL;
        ALTER TABLE decoder.decoder_scripts ALTER COLUMN long_fw DROP NOT NULL;

        -- 5. Drop old unique constraint on (sku, long_fw) if present
        ALTER TABLE decoder.decoder_scripts DROP CONSTRAINT IF EXISTS uq_decoder_sku_long_fw;
        ALTER TABLE decoder.decoder_scripts DROP CONSTRAINT IF EXISTS UQ_decoder_scripts_sku_long_fw;

        -- 6. Sync existing records: if item_code is null but sku is present, copy; if fw_version is null, sync from fw_code or long_fw
        UPDATE decoder.decoder_scripts
        SET item_code = COALESCE(item_code, sku),
            fw_version = COALESCE(fw_version, fw_code, long_fw),
            fw_code = COALESCE(fw_code, fw_version, long_fw)
        WHERE item_code IS NULL OR fw_version IS NULL;
    END IF;
END $$;

-- 7. Indexes
CREATE INDEX IF NOT EXISTS idx_decoder_scripts_item_code ON decoder.decoder_scripts(item_code);
CREATE INDEX IF NOT EXISTS idx_decoder_scripts_fw_code ON decoder.decoder_scripts(fw_code);
CREATE INDEX IF NOT EXISTS idx_decoder_scripts_fw_version ON decoder.decoder_scripts(fw_version);
CREATE INDEX IF NOT EXISTS idx_decoder_scripts_item_fw_version ON decoder.decoder_scripts(item_code, fw_version);

-- 8. Unique index on (item_code, fw_version) where present
CREATE UNIQUE INDEX IF NOT EXISTS uq_idx_decoder_item_fw_version
ON decoder.decoder_scripts (LOWER(TRIM(item_code)), LOWER(TRIM(COALESCE(fw_version, fw_code))))
WHERE item_code IS NOT NULL AND (fw_version IS NOT NULL OR fw_code IS NOT NULL);

-- 9. Refresh View: decoder.v_memmap_decoders
DROP VIEW IF EXISTS decoder.v_memmap_decoders CASCADE;
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

-- 10. Role Grants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA decoder TO itest_system_user;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA decoder TO itest_system_user;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA decoder TO itest_plugins_user;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA decoder TO itest_plugins_user;
    END IF;
END $$;
