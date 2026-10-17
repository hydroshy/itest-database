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
