-- ==============================================================================
-- ITEST DATABASE SCHEMA: DEVICES
-- Dedicated schema for Devices, Packets, and Gateway Test Sessions
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS devices;

-- 1. Devices Table
CREATE TABLE IF NOT EXISTS devices.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dev_eui VARCHAR(32),
    serial_number VARCHAR(100),
    network_id VARCHAR(100),
    device_name VARCHAR(255) DEFAULT 'Device',
    device_type VARCHAR(100) DEFAULT 'end_device',
    plugin_id VARCHAR(128) DEFAULT 'device',
    sku VARCHAR(100),
    so_id UUID,
    so_number VARCHAR(100),
    wa_id UUID,
    wa_number VARCHAR(100),
    item_code VARCHAR(100),
    status VARCHAR(50) DEFAULT 'idle',
    last_seen TIMESTAMPTZ,
    total_packets INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_devices_dev_eui UNIQUE (dev_eui)
);

CREATE INDEX IF NOT EXISTS idx_devices_dev_eui ON devices.devices(dev_eui);
CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_serial_number ON devices.devices(serial_number) WHERE serial_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_devices_network_id ON devices.devices(network_id);
CREATE INDEX IF NOT EXISTS idx_devices_device_type ON devices.devices(device_type);
CREATE INDEX IF NOT EXISTS idx_devices_plugin_id ON devices.devices(plugin_id);
CREATE INDEX IF NOT EXISTS idx_devices_sku ON devices.devices(sku);
CREATE INDEX IF NOT EXISTS idx_devices_so_id ON devices.devices(so_id);
CREATE INDEX IF NOT EXISTS idx_devices_so_number ON devices.devices(so_number);
CREATE INDEX IF NOT EXISTS idx_devices_wa_id ON devices.devices(wa_id);
CREATE INDEX IF NOT EXISTS idx_devices_wa_number ON devices.devices(wa_number);
CREATE INDEX IF NOT EXISTS idx_devices_item_code ON devices.devices(item_code);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices.devices(status);
CREATE INDEX IF NOT EXISTS idx_devices_last_seen ON devices.devices(last_seen DESC);
CREATE INDEX IF NOT EXISTS idx_devices_metadata_gin ON devices.devices USING GIN (metadata);

-- Trigger for sync_device_serial_and_deveui and updated_at
CREATE OR REPLACE FUNCTION devices.sync_device_serial_and_deveui()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.serial_number IS NULL OR TRIM(NEW.serial_number) = '') AND (NEW.dev_eui IS NOT NULL AND TRIM(NEW.dev_eui) <> '') THEN
        NEW.serial_number = NEW.dev_eui;
    ELSIF (NEW.dev_eui IS NULL OR TRIM(NEW.dev_eui) = '') AND (NEW.serial_number IS NOT NULL AND TRIM(NEW.serial_number) <> '') THEN
        NEW.dev_eui = NEW.serial_number;
    END IF;

    IF NEW.device_type IS NULL OR TRIM(NEW.device_type) = '' THEN
        NEW.device_type = 'end_device';
    END IF;
    IF NEW.plugin_id IS NULL OR TRIM(NEW.plugin_id) = '' THEN
        NEW.plugin_id = 'device';
    END IF;
    IF NEW.device_name IS NULL OR TRIM(NEW.device_name) = '' THEN
        NEW.device_name = 'Device ' || COALESCE(NEW.serial_number, NEW.dev_eui, NEW.id::text);
    END IF;

    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_device_serial_and_deveui ON devices.devices;
CREATE TRIGGER trg_sync_device_serial_and_deveui
BEFORE INSERT OR UPDATE ON devices.devices
FOR EACH ROW
EXECUTE FUNCTION devices.sync_device_serial_and_deveui();

-- 2. Gateway Test Sessions Table
CREATE TABLE IF NOT EXISTS devices.gateway_test_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_name VARCHAR(255),
    gateway_id VARCHAR(64),
    gateway_name VARCHAR(255),
    status VARCHAR(50) NOT NULL DEFAULT 'REGISTERED',
    so_number VARCHAR(100),
    wa_number VARCHAR(100),
    serial_number VARCHAR(100),
    eui VARCHAR(64),
    item_code VARCHAR(100),
    sku VARCHAR(100),
    gateway_notes TEXT,
    hardware_version VARCHAR(50),
    firmware_version VARCHAR(50),
    mechanical_version VARCHAR(50),
    lte_module_serial_number VARCHAR(100),
    lte_module_imei VARCHAR(100),
    gateway_ip VARCHAR(45),
    internet_test_type VARCHAR(20) DEFAULT 'ETHERNET',
    region_test VARCHAR(50),
    network_server_id UUID,
    lorawan_frequency_plan VARCHAR(50),
    config_snapshot JSONB DEFAULT '{}'::jsonb,
    forwarder_config JSONB DEFAULT '{}'::jsonb,
    total_packets INTEGER NOT NULL DEFAULT 0,
    unique_devices INTEGER NOT NULL DEFAULT 0,
    started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    start_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    summary JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_gateway_id ON devices.gateway_test_sessions(gateway_id);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_gateway_name ON devices.gateway_test_sessions(gateway_name);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_status ON devices.gateway_test_sessions(status);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_start_time ON devices.gateway_test_sessions(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_started_at ON devices.gateway_test_sessions(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_serial_number ON devices.gateway_test_sessions(serial_number);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_eui ON devices.gateway_test_sessions(eui);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_so_number ON devices.gateway_test_sessions(so_number);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_wa_number ON devices.gateway_test_sessions(wa_number);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_item_code ON devices.gateway_test_sessions(item_code);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_gateway_ip ON devices.gateway_test_sessions(gateway_ip);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_network_server_id ON devices.gateway_test_sessions(network_server_id);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_config_snapshot_gin ON devices.gateway_test_sessions USING GIN (config_snapshot);

DROP TRIGGER IF EXISTS trg_devices_gateway_test_sessions_updated_at ON devices.gateway_test_sessions;
CREATE TRIGGER trg_devices_gateway_test_sessions_updated_at
BEFORE UPDATE ON devices.gateway_test_sessions
FOR EACH ROW
EXECUTE FUNCTION devices.update_updated_at_column();

-- Trigger for gateway_test_sessions time & name sync
CREATE OR REPLACE FUNCTION devices.sync_gateway_test_sessions_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.eui IS NULL AND NEW.gateway_id IS NOT NULL THEN
        NEW.eui = NEW.gateway_id;
    ELSIF NEW.gateway_id IS NULL AND NEW.eui IS NOT NULL THEN
        NEW.gateway_id = NEW.eui;
    END IF;

    IF NEW.gateway_name IS NULL AND NEW.gateway_id IS NOT NULL THEN
        NEW.gateway_name = NEW.gateway_id;
    END IF;

    IF NEW.session_name IS NULL THEN
        NEW.session_name = 'GW-' || COALESCE(NEW.serial_number, NEW.gateway_id, 'SESSION');
    END IF;

    IF NEW.started_at IS NOT NULL AND NEW.start_time IS NULL THEN
        NEW.start_time = NEW.started_at;
    ELSIF NEW.start_time IS NOT NULL AND NEW.started_at IS NULL THEN
        NEW.started_at = NEW.start_time;
    END IF;
    IF NEW.ended_at IS NOT NULL AND NEW.end_time IS NULL THEN
        NEW.end_time = NEW.ended_at;
    ELSIF NEW.end_time IS NOT NULL AND NEW.ended_at IS NULL THEN
        NEW.ended_at = NEW.end_time;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_gateway_test_sessions_columns ON devices.gateway_test_sessions;
CREATE TRIGGER trg_sync_gateway_test_sessions_columns
BEFORE INSERT OR UPDATE ON devices.gateway_test_sessions
FOR EACH ROW
EXECUTE FUNCTION devices.sync_gateway_test_sessions_columns();

-- 3. Device Packets Table
CREATE TABLE IF NOT EXISTS devices.device_packets (
    id BIGSERIAL PRIMARY KEY,
    device_id UUID REFERENCES devices.devices(id) ON DELETE CASCADE,
    dev_eui VARCHAR(32),
    session_id UUID REFERENCES devices.gateway_test_sessions(id) ON DELETE SET NULL,
    packet_type VARCHAR(50) DEFAULT 'uplink',
    f_port INTEGER,
    f_cnt BIGINT,
    rssi NUMERIC(6, 2),
    snr NUMERIC(6, 2),
    frequency NUMERIC(10, 3),
    raw_payload TEXT,
    payload_raw TEXT,
    decoded_payload JSONB DEFAULT '{}'::jsonb,
    payload_decoded JSONB DEFAULT '{}'::jsonb,
    rf_info JSONB DEFAULT '{}'::jsonb,
    received_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_devices_packets_device_id ON devices.device_packets(device_id);
CREATE INDEX IF NOT EXISTS idx_devices_packets_dev_eui ON devices.device_packets(dev_eui);
CREATE INDEX IF NOT EXISTS idx_devices_packets_session_id ON devices.device_packets(session_id);
CREATE INDEX IF NOT EXISTS idx_devices_packets_packet_type ON devices.device_packets(packet_type);
CREATE INDEX IF NOT EXISTS idx_devices_packets_created_at ON devices.device_packets(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_devices_packets_received_at ON devices.device_packets(received_at DESC);
CREATE INDEX IF NOT EXISTS idx_devices_packets_decoded_payload_gin ON devices.device_packets USING GIN (decoded_payload);
CREATE INDEX IF NOT EXISTS idx_devices_packets_rf_info_gin ON devices.device_packets USING GIN (rf_info);

-- Synchronization trigger for device_packets
CREATE OR REPLACE FUNCTION devices.sync_device_packets_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync raw_payload and payload_raw
    IF NEW.raw_payload IS NOT NULL AND NEW.payload_raw IS NULL THEN
        NEW.payload_raw = NEW.raw_payload;
    ELSIF NEW.payload_raw IS NOT NULL AND NEW.raw_payload IS NULL THEN
        NEW.raw_payload = NEW.payload_raw;
    END IF;

    -- Sync decoded_payload and payload_decoded
    IF NEW.decoded_payload IS NOT NULL AND (NEW.payload_decoded IS NULL OR NEW.payload_decoded = '{}'::jsonb) THEN
        NEW.payload_decoded = NEW.decoded_payload;
    ELSIF NEW.payload_decoded IS NOT NULL AND (NEW.decoded_payload IS NULL OR NEW.decoded_payload = '{}'::jsonb) THEN
        NEW.decoded_payload = NEW.payload_decoded;
    END IF;

    -- Sync rf_info with rssi, snr, frequency
    IF NEW.rf_info IS NOT NULL AND NEW.rf_info <> '{}'::jsonb THEN
        IF NEW.rssi IS NULL AND (NEW.rf_info->>'rssi') IS NOT NULL THEN
            NEW.rssi = (NEW.rf_info->>'rssi')::numeric;
        END IF;
        IF NEW.snr IS NULL AND (NEW.rf_info->>'snr') IS NOT NULL THEN
            NEW.snr = (NEW.rf_info->>'snr')::numeric;
        END IF;
        IF NEW.frequency IS NULL AND (NEW.rf_info->>'frequency') IS NOT NULL THEN
            NEW.frequency = (NEW.rf_info->>'frequency')::numeric;
        END IF;
    ELSIF NEW.rssi IS NOT NULL OR NEW.snr IS NOT NULL OR NEW.frequency IS NOT NULL THEN
        NEW.rf_info = jsonb_build_object('rssi', NEW.rssi, 'snr', NEW.snr, 'frequency', NEW.frequency);
    END IF;

    -- Resolve device_id from dev_eui if device_id is NULL
    IF NEW.device_id IS NULL AND NEW.dev_eui IS NOT NULL THEN
        SELECT id INTO NEW.device_id FROM devices.devices WHERE dev_eui = NEW.dev_eui LIMIT 1;
    -- Or resolve dev_eui from device_id if dev_eui is NULL
    ELSIF NEW.dev_eui IS NULL AND NEW.device_id IS NOT NULL THEN
        SELECT dev_eui INTO NEW.dev_eui FROM devices.devices WHERE id = NEW.device_id LIMIT 1;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_device_packets_columns ON devices.device_packets;
CREATE TRIGGER trg_sync_device_packets_columns
BEFORE INSERT OR UPDATE ON devices.device_packets
FOR EACH ROW
EXECUTE FUNCTION devices.sync_device_packets_columns();

-- 4. Compatibility Views inside devices schema
CREATE OR REPLACE VIEW devices.testing_devices AS SELECT * FROM devices.devices;
CREATE OR REPLACE VIEW devices.testing_packets AS SELECT * FROM devices.device_packets;
