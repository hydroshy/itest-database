-- ==============================================================================
-- ITEST DATABASE SCHEMA: DEVICES
-- Dedicated schema for Devices, Packets, and Gateway Test Sessions
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS devices;

-- 1. Devices Table
CREATE TABLE IF NOT EXISTS devices.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dev_eui VARCHAR(32) NOT NULL,
    device_name VARCHAR(100),
    sku VARCHAR(100),
    status VARCHAR(50) DEFAULT 'idle',
    last_seen TIMESTAMPTZ,
    total_packets INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_devices_dev_eui UNIQUE (dev_eui)
);

CREATE INDEX IF NOT EXISTS idx_devices_dev_eui ON devices.devices(dev_eui);
CREATE INDEX IF NOT EXISTS idx_devices_sku ON devices.devices(sku);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices.devices(status);
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices.devices(last_seen DESC);
CREATE INDEX IF NOT EXISTS idx_devices_metadata_gin ON devices.devices USING GIN (metadata);

-- Trigger for devices.updated_at
CREATE OR REPLACE FUNCTION devices.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_devices_updated_at ON devices.devices;
CREATE TRIGGER trg_devices_updated_at
BEFORE UPDATE ON devices.devices
FOR EACH ROW
EXECUTE FUNCTION devices.update_updated_at_column();

-- 2. Gateway Test Sessions Table
CREATE TABLE IF NOT EXISTS devices.gateway_test_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_name VARCHAR(100) NOT NULL,
    gateway_id VARCHAR(64) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed', 'stopped')),
    total_packets INTEGER NOT NULL DEFAULT 0,
    unique_devices INTEGER NOT NULL DEFAULT 0,
    start_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_gateway_id ON devices.gateway_test_sessions(gateway_id);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_status ON devices.gateway_test_sessions(status);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_start_time ON devices.gateway_test_sessions(start_time DESC);

DROP TRIGGER IF EXISTS trg_devices_gateway_test_sessions_updated_at ON devices.gateway_test_sessions;
CREATE TRIGGER trg_devices_gateway_test_sessions_updated_at
BEFORE UPDATE ON devices.gateway_test_sessions
FOR EACH ROW
EXECUTE FUNCTION devices.update_updated_at_column();

-- 3. Device Packets Table
CREATE TABLE IF NOT EXISTS devices.device_packets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dev_eui VARCHAR(32) NOT NULL,
    session_id UUID REFERENCES devices.gateway_test_sessions(id) ON DELETE SET NULL,
    f_port INTEGER,
    f_cnt INTEGER,
    rssi NUMERIC(6, 2),
    snr NUMERIC(6, 2),
    frequency NUMERIC(10, 3),
    payload_raw TEXT,
    payload_decoded JSONB,
    received_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_devices_packets_dev_eui ON devices.device_packets(dev_eui);
CREATE INDEX IF NOT EXISTS idx_devices_packets_session_id ON devices.device_packets(session_id);
CREATE INDEX IF NOT EXISTS idx_devices_packets_received_at ON devices.device_packets(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_devices_packets_payload_decoded_gin ON devices.device_packets USING GIN (payload_decoded);

-- 4. Compatibility Views inside devices schema
CREATE OR REPLACE VIEW devices.testing_devices AS SELECT * FROM devices.devices;
CREATE OR REPLACE VIEW devices.testing_packets AS SELECT * FROM devices.device_packets;
