-- ==============================================================================
-- ITEST DATABASE SCHEMA: DECODER
-- Dedicated schema for LoRaWAN & IoT payload decoders / codecs
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS decoder;

-- 1. Decoder Scripts Table
CREATE TABLE IF NOT EXISTS decoder.decoder_scripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(100) NOT NULL,
    long_fw VARCHAR(100) NOT NULL,
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
    created_by VARCHAR(100) DEFAULT 'system',
    CONSTRAINT uq_decoder_sku_long_fw UNIQUE (sku, long_fw)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_decoder_sku ON decoder.decoder_scripts(sku);
CREATE INDEX IF NOT EXISTS idx_decoder_protocol ON decoder.decoder_scripts(protocol);
CREATE INDEX IF NOT EXISTS idx_decoder_is_active ON decoder.decoder_scripts(is_active);
CREATE INDEX IF NOT EXISTS idx_decoder_sample_decoded_gin ON decoder.decoder_scripts USING GIN (sample_decoded);
CREATE INDEX IF NOT EXISTS idx_decoder_metadata_gin ON decoder.decoder_scripts USING GIN (metadata);

-- Trigger Function for Updated At
CREATE OR REPLACE FUNCTION decoder.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_decoder_scripts_updated_at ON decoder.decoder_scripts;
CREATE TRIGGER trg_decoder_scripts_updated_at
BEFORE UPDATE ON decoder.decoder_scripts
FOR EACH ROW
EXECUTE FUNCTION decoder.update_updated_at_column();

-- 2. View: v_memmap_decoders
CREATE OR REPLACE VIEW decoder.v_memmap_decoders AS
SELECT 
    COALESCE(p.sku, d.sku) AS sku,
    COALESCE(p.long_fw, d.long_fw) AS long_fw,
    p.id AS memmap_profile_id,
    p.name AS memmap_profile_name,
    p.short_fw AS memmap_short_fw,
    d.id AS decoder_id,
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
