-- ==============================================================================
-- ITEST DATABASE SCHEMA: DECODER
-- Dedicated schema for LoRaWAN & IoT payload decoders / codecs
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS decoder;

-- 1. Decoder Scripts Table
CREATE TABLE IF NOT EXISTS decoder.decoder_scripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255),
    sku VARCHAR(100),
    long_fw VARCHAR(100),
    item_code VARCHAR(100),
    fw_code VARCHAR(50),
    fw_version VARCHAR(50),
    protocol VARCHAR(50) NOT NULL DEFAULT 'lorawan',
    script TEXT NOT NULL,
    description TEXT,
    input_format VARCHAR(20) NOT NULL DEFAULT 'hex' CHECK (input_format IN ('hex', 'base64')),
    sample_payload TEXT,
    sample_fport INTEGER DEFAULT 1 CHECK (sample_fport >= 1 AND sample_fport <= 223),
    sample_decoded JSONB,
    is_active BOOLEAN NOT NULL DEFAULT true,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100) DEFAULT 'system'
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_decoder_name ON decoder.decoder_scripts(name);
CREATE INDEX IF NOT EXISTS idx_decoder_sku ON decoder.decoder_scripts(sku);
CREATE INDEX IF NOT EXISTS idx_decoder_item_code ON decoder.decoder_scripts(item_code);
CREATE INDEX IF NOT EXISTS idx_decoder_fw_code ON decoder.decoder_scripts(fw_code);
CREATE INDEX IF NOT EXISTS idx_decoder_fw_version ON decoder.decoder_scripts(fw_version);
CREATE INDEX IF NOT EXISTS idx_decoder_item_fw ON decoder.decoder_scripts(item_code, fw_code);
CREATE INDEX IF NOT EXISTS idx_decoder_item_fw_version ON decoder.decoder_scripts(item_code, fw_version);
CREATE UNIQUE INDEX IF NOT EXISTS uq_idx_decoder_item_fw_version
ON decoder.decoder_scripts (LOWER(TRIM(item_code)), LOWER(TRIM(COALESCE(fw_version, fw_code))))
WHERE item_code IS NOT NULL AND (fw_version IS NOT NULL OR fw_code IS NOT NULL);
CREATE INDEX IF NOT EXISTS idx_decoder_protocol ON decoder.decoder_scripts(protocol);
CREATE INDEX IF NOT EXISTS idx_decoder_is_active ON decoder.decoder_scripts(is_active);
CREATE INDEX IF NOT EXISTS idx_decoder_sample_decoded_gin ON decoder.decoder_scripts USING GIN (sample_decoded);
CREATE INDEX IF NOT EXISTS idx_decoder_metadata_gin ON decoder.decoder_scripts USING GIN (metadata);

-- Trigger Function for Updated At & Default Name
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

-- 2. View: v_memmap_decoders
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
