-- Migration: 001_create_decoder_schema_and_tables.sql
-- Dedicated schema for LoRaWAN & IoT payload decoders / codecs
-- Linked to memmap profiles (sku, long_fw)

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

-- Trigger for updated_at
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

-- Migrate existing records from plugins_schema.decoder_scripts if exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'plugins_schema' AND table_name = 'decoder_scripts'
        AND table_type = 'BASE TABLE'
    ) THEN
        INSERT INTO decoder.decoder_scripts (
            id, sku, long_fw, protocol, script, description, input_format, 
            sample_payload, sample_fport, sample_decoded, is_active, metadata, 
            created_at, updated_at, created_by
        )
        SELECT 
            id, sku, long_fw, protocol, script, description, input_format, 
            sample_payload, sample_fport, sample_decoded, is_active, metadata, 
            created_at, updated_at, created_by
        FROM plugins_schema.decoder_scripts
        ON CONFLICT (sku, long_fw) DO NOTHING;
    END IF;
END $$;

-- 2. View: v_memmap_decoders
-- Links memmap_manager.memmap_profiles with decoder.decoder_scripts
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

-- 3. Seed Reference Decoder
INSERT INTO decoder.decoder_scripts (
    sku, long_fw, protocol, script, description, input_format, sample_payload, sample_fport, sample_decoded, is_active
) VALUES (
    'STANDARD-LORAWAN',
    'DEFAULT',
    'lorawan',
    'function decodeUplink(input) {
  var bytes = input.bytes;
  var port = input.fPort;
  var data = {};
  if (bytes && bytes.length >= 2) {
    data.temperature = ((bytes[0] << 8) | bytes[1]) / 100.0;
  }
  if (bytes && bytes.length >= 4) {
    data.humidity = ((bytes[2] << 8) | bytes[3]) / 100.0;
  }
  return { data: data };
}',
    'Standard LoRaWAN environmental sensor codec (ChirpStack v4 / TTN v3)',
    'hex',
    '0a5015b3',
    1,
    '{"temperature": 26.4, "humidity": 55.55}'::jsonb,
    true
)
ON CONFLICT (sku, long_fw) DO UPDATE SET
    script = EXCLUDED.script,
    description = EXCLUDED.description,
    sample_payload = EXCLUDED.sample_payload,
    sample_fport = EXCLUDED.sample_fport,
    sample_decoded = EXCLUDED.sample_decoded,
    updated_at = CURRENT_TIMESTAMP;

-- 4. Backward-compatibility Views in plugins_schema
-- If plugins_schema exists, create views pointing to decoder schema
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'plugins_schema') THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'plugins_schema' AND table_name = 'decoder_scripts'
            AND table_type = 'BASE TABLE'
        ) THEN
            DROP TABLE IF EXISTS plugins_schema.decoder_scripts CASCADE;
        END IF;

        EXECUTE 'CREATE OR REPLACE VIEW plugins_schema.decoder_scripts AS SELECT * FROM decoder.decoder_scripts';
        EXECUTE 'CREATE OR REPLACE VIEW plugins_schema.v_memmap_decoders AS SELECT * FROM decoder.v_memmap_decoders';
    END IF;
END $$;

-- 5. Idempotent Runtime Grants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
        GRANT USAGE, CREATE ON SCHEMA decoder TO itest_system_user;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA decoder TO itest_system_user;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA decoder TO itest_system_user;
        GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA decoder TO itest_system_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA decoder GRANT ALL PRIVILEGES ON TABLES TO itest_system_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA decoder GRANT ALL PRIVILEGES ON SEQUENCES TO itest_system_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA decoder GRANT ALL PRIVILEGES ON ROUTINES TO itest_system_user;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
        GRANT USAGE ON SCHEMA decoder TO itest_plugins_user;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA decoder TO itest_plugins_user;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA decoder TO itest_plugins_user;
        GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA decoder TO itest_plugins_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA decoder GRANT ALL PRIVILEGES ON TABLES TO itest_plugins_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA decoder GRANT ALL PRIVILEGES ON SEQUENCES TO itest_plugins_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA decoder GRANT ALL PRIVILEGES ON ROUTINES TO itest_plugins_user;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
        GRANT USAGE ON SCHEMA decoder TO itest_ops_user;
        GRANT SELECT ON ALL TABLES IN SCHEMA decoder TO itest_ops_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA decoder GRANT SELECT ON TABLES TO itest_ops_user;
    END IF;
END $$;
