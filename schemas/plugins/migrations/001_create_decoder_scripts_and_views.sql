-- ==============================================================================
-- ITEST PLATFORM - PLUGIN DECODER MIGRATION (POSTGRESQL 17)
-- ==============================================================================
-- Migration: 001_create_decoder_scripts_and_views.sql
-- Module: itest-plugins / decoder
-- Schema: plugins_schema
-- Description:
--   1. Create table plugins_schema.decoder_scripts for storing LoRaWAN codec/decoder scripts
--      bound to unique (sku, long_fw) pairs.
--   2. Create indexes and updated_at triggers.
--   3. Create view plugins_schema.v_memmap_decoders linking memmap_profiles with decoder_scripts.
--   4. Seed default standard LoRaWAN decoder template.
--   5. Idempotent grants for runtime roles (itest_system_user, itest_plugins_user, itest_ops_user).
-- ==============================================================================

-- 1. Ensure extensions and schema exist
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE SCHEMA IF NOT EXISTS plugins_schema;

-- 2. Trigger function for updated_at in plugins_schema
CREATE OR REPLACE FUNCTION plugins_schema.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Table plugins_schema.decoder_scripts
CREATE TABLE IF NOT EXISTS plugins_schema."decoder_scripts" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "name" VARCHAR(255) NOT NULL,
  "sku" VARCHAR(100) NOT NULL,
  "long_fw" VARCHAR(100) NOT NULL,
  "protocol" VARCHAR(50) NOT NULL DEFAULT 'lorawan',
  "script" TEXT NOT NULL,
  "description" TEXT,
  "input_format" VARCHAR(50) NOT NULL DEFAULT 'hex',
  "sample_payload" TEXT,
  "sample_fport" INTEGER NOT NULL DEFAULT 1,
  "sample_decoded" JSONB DEFAULT '{}'::jsonb,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "metadata" JSONB DEFAULT '{}'::jsonb,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_by" VARCHAR(100) DEFAULT 'system',
  CONSTRAINT "UQ_decoder_scripts_sku_long_fw" UNIQUE ("sku", "long_fw")
);

-- Indices
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_sku" ON plugins_schema."decoder_scripts" ("sku");
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_long_fw" ON plugins_schema."decoder_scripts" ("long_fw");
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_sku_long_fw" ON plugins_schema."decoder_scripts" ("sku", "long_fw");
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_is_active" ON plugins_schema."decoder_scripts" ("is_active");
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_sample_decoded" ON plugins_schema."decoder_scripts" USING GIN ("sample_decoded");
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_metadata" ON plugins_schema."decoder_scripts" USING GIN ("metadata");

-- Trigger
DROP TRIGGER IF EXISTS "trg_decoder_scripts_updated_at" ON plugins_schema."decoder_scripts";
CREATE TRIGGER "trg_decoder_scripts_updated_at"
  BEFORE UPDATE ON plugins_schema."decoder_scripts"
  FOR EACH ROW
  EXECUTE FUNCTION plugins_schema.set_current_timestamp_updated_at();

-- 4. View plugins_schema.v_memmap_decoders
-- Joins memmap_manager.memmap_profiles with plugins_schema.decoder_scripts
-- Enables UI and Backend to query SKU/LONG_FW coverage and decoder configuration status
CREATE OR REPLACE VIEW plugins_schema.v_memmap_decoders AS
SELECT 
  mp.id AS memmap_profile_id,
  mp.name AS profile_name,
  COALESCE(mp.sku, ds.sku) AS sku,
  COALESCE(mp.long_fw, ds.long_fw) AS long_fw,
  mp.short_fw,
  ds.id AS decoder_id,
  ds.name AS decoder_name,
  ds.protocol,
  ds.input_format,
  ds.sample_payload,
  ds.sample_fport,
  ds.sample_decoded,
  COALESCE(ds.is_active, false) AS has_active_decoder,
  (ds.id IS NOT NULL) AS is_configured,
  ds.created_at AS decoder_created_at,
  ds.updated_at AS decoder_updated_at,
  ds.created_by AS decoder_created_by
FROM memmap_manager.memmap_profiles mp
FULL OUTER JOIN plugins_schema.decoder_scripts ds
  ON LOWER(TRIM(mp.sku)) = LOWER(TRIM(ds.sku))
 AND LOWER(TRIM(mp.long_fw)) = LOWER(TRIM(ds.long_fw));

-- 5. Seed Standard Default Template
INSERT INTO plugins_schema."decoder_scripts" (
  "name",
  "sku",
  "long_fw",
  "protocol",
  "script",
  "description",
  "input_format",
  "sample_payload",
  "sample_fport",
  "sample_decoded",
  "is_active",
  "metadata",
  "created_by"
) VALUES (
  'Standard LoRaWAN Sensor Decoder Template',
  'STANDARD-LORAWAN',
  'DEFAULT',
  'lorawan',
  '/**
 * Standard LoRaWAN Uplink Decoder
 * Compatible with ChirpStack v4 and TTN v3
 *
 * @param {Object} input - { bytes: number[], fPort: number, variables: Object }
 * @returns {Object} { data: Object, warnings: string[], errors: string[] }
 */
function decodeUplink(input) {
  var bytes = input.bytes || [];
  var fPort = input.fPort || 1;
  var data = {};
  var warnings = [];
  var errors = [];

  if (bytes.length >= 2) {
    var tempRaw = (bytes[0] << 8) | bytes[1];
    if (tempRaw > 32767) tempRaw -= 65536;
    data.temperature = parseFloat((tempRaw / 100.0).toFixed(2));
  }
  if (bytes.length >= 4) {
    var humRaw = (bytes[2] << 8) | bytes[3];
    data.humidity = parseFloat((humRaw / 100.0).toFixed(2));
  }
  if (bytes.length >= 6) {
    var battRaw = (bytes[4] << 8) | bytes[5];
    data.battery_mv = battRaw;
  }

  return {
    data: data,
    warnings: warnings,
    errors: errors
  };
}

// Backward compatibility for TTN / ChirpStack v3
function Decode(fPort, bytes) {
  var res = decodeUplink({ bytes: bytes, fPort: fPort });
  return res.data;
}',
  'Standard reference JavaScript codec for LoRaWAN sensor uplinks decoding temperature, humidity, and battery voltage.',
  'hex',
  '0A2813880D1A',
  1,
  '{"temperature": 26.0, "humidity": 50.0, "battery_mv": 3354}'::jsonb,
  true,
  '{"author": "ITEST DATABASE", "version": "1.0.0", "standard": "ChirpStack v4 / TTN v3"}'::jsonb,
  'system'
) ON CONFLICT ("sku", "long_fw") DO UPDATE SET
  "name" = EXCLUDED."name",
  "script" = EXCLUDED."script",
  "description" = EXCLUDED."description",
  "sample_payload" = EXCLUDED."sample_payload",
  "sample_decoded" = EXCLUDED."sample_decoded",
  "updated_at" = CURRENT_TIMESTAMP;

-- 6. Idempotent Runtime Grants
DO $$
BEGIN
  -- Grant to itest_system_user (Backend API)
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE ON SCHEMA plugins_schema TO itest_system_user;
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE plugins_schema."decoder_scripts" TO itest_system_user;
    GRANT SELECT ON TABLE plugins_schema."v_memmap_decoders" TO itest_system_user;
    GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA plugins_schema TO itest_system_user;
  END IF;

  -- Grant to itest_plugins_user (Plugins Engine)
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE, CREATE ON SCHEMA plugins_schema TO itest_plugins_user;
    GRANT ALL PRIVILEGES ON TABLE plugins_schema."decoder_scripts" TO itest_plugins_user;
    GRANT ALL PRIVILEGES ON TABLE plugins_schema."v_memmap_decoders" TO itest_plugins_user;
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA plugins_schema TO itest_plugins_user;

    -- Also allow itest_plugins_user to read memmap_profiles for cross-schema view
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'memmap_manager') THEN
      GRANT USAGE ON SCHEMA memmap_manager TO itest_plugins_user;
      GRANT SELECT ON TABLE memmap_manager."memmap_profiles" TO itest_plugins_user;
    END IF;
  END IF;

  -- Grant to itest_ops_user (Telemetry & Ops Monitoring)
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT USAGE ON SCHEMA plugins_schema TO itest_ops_user;
    GRANT SELECT ON TABLE plugins_schema."decoder_scripts" TO itest_ops_user;
    GRANT SELECT ON TABLE plugins_schema."v_memmap_decoders" TO itest_ops_user;
  END IF;
END $$;
