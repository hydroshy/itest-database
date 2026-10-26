-- ==============================================================================
-- ITEST-PLUGINS - STANDALONE PLUGINS & PROTOCOLS SCHEMA (POSTGRESQL 17)
-- ==============================================================================
-- File: schemas/plugins/schema.sql
-- Description: Database schema for decoupled plugins (Modbus, LoRaWAN, MQTT,
--              ChirpStack, Telemetry Engine, Codecs, and Device Profiles).
-- Schema: plugins_schema
-- ==============================================================================

SET search_path TO plugins_schema, public;

-- 1. Plugin Configurations Store
CREATE TABLE IF NOT EXISTS plugins_schema."plugin_configs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "plugin_id" VARCHAR(100) NOT NULL,
  "config_key" VARCHAR(100) NOT NULL,
  "config_value" JSONB NOT NULL DEFAULT '{}',
  "is_encrypted" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMP NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT "UQ_plugin_config_key" UNIQUE ("plugin_id", "config_key")
);

-- 2. Device Profiles & Codec Registry
CREATE TABLE IF NOT EXISTS plugins_schema."device_profiles" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "profile_name" VARCHAR(255) NOT NULL,
  "protocol" VARCHAR(50) NOT NULL,
  "manufacturer" VARCHAR(100),
  "model" VARCHAR(100),
  "payload_codec_id" VARCHAR(100),
  "codec_script" TEXT,
  "parameters_schema" JSONB DEFAULT '{}',
  "created_at" TIMESTAMP NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMP NOT NULL DEFAULT now()
);

-- 3. Plugin Channel & Connection Settings (Modbus RTU/TCP, MQTT, LoRaWAN gateways)
CREATE TABLE IF NOT EXISTS plugins_schema."connection_channels" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "channel_name" VARCHAR(255) NOT NULL,
  "protocol" VARCHAR(50) NOT NULL,
  "connection_type" VARCHAR(50) NOT NULL, -- e.g., 'serial', 'tcp', 'websocket', 'mqtt'
  "endpoint" VARCHAR(255) NOT NULL,
  "options" JSONB DEFAULT '{}',
  "status" VARCHAR(50) NOT NULL DEFAULT 'disconnected',
  "last_connected_at" TIMESTAMP,
  "created_at" TIMESTAMP NOT NULL DEFAULT now(),
  "updated_at" TIMESTAMP NOT NULL DEFAULT now()
);

-- 4. Real-time Telemetry Data Stream (Optimized for time-series / time-range queries)
CREATE TABLE IF NOT EXISTS plugins_schema."telemetry_records" (
  "id" BIGSERIAL PRIMARY KEY,
  "device_id" VARCHAR(100) NOT NULL,
  "metric_name" VARCHAR(100) NOT NULL,
  "metric_value" NUMERIC(18, 6),
  "string_value" TEXT,
  "raw_payload" JSONB,
  "quality" SMALLINT NOT NULL DEFAULT 192, -- OPC UA / Industrial quality flag (192 = Good)
  "recorded_at" TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- 5. Command & Downlink History
CREATE TABLE IF NOT EXISTS plugins_schema."command_logs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "device_id" VARCHAR(100) NOT NULL,
  "command_type" VARCHAR(100) NOT NULL,
  "payload" JSONB DEFAULT '{}',
  "status" VARCHAR(50) NOT NULL DEFAULT 'pending', -- pending, sent, acknowledged, failed
  "executed_by" VARCHAR(255),
  "sent_at" TIMESTAMPTZ,
  "acknowledged_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- 6. Plugin-specific Event Triggers and Rules
CREATE TABLE IF NOT EXISTS plugins_schema."telemetry_rules" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "rule_name" VARCHAR(255) NOT NULL,
  "device_id" VARCHAR(100),
  "metric_name" VARCHAR(100) NOT NULL,
  "operator" VARCHAR(20) NOT NULL, -- '>', '<', '=', '!=', 'between'
  "threshold_low" NUMERIC(18, 6),
  "threshold_high" NUMERIC(18, 6),
  "action_type" VARCHAR(50) NOT NULL, -- 'alert', 'webhook', 'downlink'
  "action_config" JSONB DEFAULT '{}',
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMP NOT NULL DEFAULT now()
);

-- Indexes for time-series and search acceleration
CREATE INDEX IF NOT EXISTS "idx_plugin_configs_plugin" ON plugins_schema."plugin_configs"("plugin_id");
CREATE INDEX IF NOT EXISTS "idx_telemetry_device_time" ON plugins_schema."telemetry_records"("device_id", "recorded_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_telemetry_metric_time" ON plugins_schema."telemetry_records"("metric_name", "recorded_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_telemetry_recorded_at" ON plugins_schema."telemetry_records"("recorded_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_command_logs_device" ON plugins_schema."command_logs"("device_id", "created_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_conn_channels_protocol" ON plugins_schema."connection_channels"("protocol");

-- ==============================================================================
-- 7. Trigger Function for Updated At
-- ==============================================================================
CREATE OR REPLACE FUNCTION plugins_schema.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- 8. Decoder Scripts Store (LoRaWAN & IoT Codecs)
-- ==============================================================================
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

CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_sku" ON plugins_schema."decoder_scripts" ("sku");
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_long_fw" ON plugins_schema."decoder_scripts" ("long_fw");
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_sku_long_fw" ON plugins_schema."decoder_scripts" ("sku", "long_fw");
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_is_active" ON plugins_schema."decoder_scripts" ("is_active");
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_sample_decoded" ON plugins_schema."decoder_scripts" USING GIN ("sample_decoded");
CREATE INDEX IF NOT EXISTS "idx_decoder_scripts_metadata" ON plugins_schema."decoder_scripts" USING GIN ("metadata");

DROP TRIGGER IF EXISTS "trg_decoder_scripts_updated_at" ON plugins_schema."decoder_scripts";
CREATE TRIGGER "trg_decoder_scripts_updated_at"
  BEFORE UPDATE ON plugins_schema."decoder_scripts"
  FOR EACH ROW
  EXECUTE FUNCTION plugins_schema.set_current_timestamp_updated_at();

-- ==============================================================================
-- 9. View: v_memmap_decoders (Bridge MemMap Profiles & Decoder Scripts)
-- ==============================================================================
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

