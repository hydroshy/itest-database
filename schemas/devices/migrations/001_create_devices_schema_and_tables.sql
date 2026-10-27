-- Migration: 001_create_devices_schema_and_tables.sql
-- Dedicated schema for Devices, Device Packets, and Gateway Test Sessions

CREATE SCHEMA IF NOT EXISTS devices;

-- 1. Devices Table
CREATE TABLE IF NOT EXISTS devices.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    dev_eui VARCHAR(32),
    serial_number VARCHAR(100),
    network_id VARCHAR(100),
    device_name VARCHAR(255) DEFAULT 'Device',
    device_type VARCHAR(100) DEFAULT 'end_device',
    plugin_id VARCHAR(128) DEFAULT 'testing',
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

-- 4. Migrate Data from existing tables if they exist
DO $$
BEGIN
    -- Migrate from system_schema.testing_devices if base table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'system_schema' AND table_name = 'testing_devices'
        AND table_type = 'BASE TABLE'
    ) THEN
        INSERT INTO devices.devices (
            id, dev_eui, device_name, sku, status, last_seen, total_packets, metadata, created_at, updated_at
        )
        SELECT 
            id, dev_eui, device_name, sku, status, last_seen, total_packets, metadata, created_at, updated_at
        FROM system_schema.testing_devices
        ON CONFLICT (dev_eui) DO UPDATE SET
            device_name = EXCLUDED.device_name,
            sku = EXCLUDED.sku,
            status = EXCLUDED.status,
            last_seen = EXCLUDED.last_seen,
            total_packets = EXCLUDED.total_packets,
            metadata = EXCLUDED.metadata,
            updated_at = EXCLUDED.updated_at;
    END IF;

    -- Migrate from lorawan_chirpstack.gateway_test_sessions if base table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions'
        AND table_type = 'BASE TABLE'
    ) THEN
        INSERT INTO devices.gateway_test_sessions (
            id, session_name, gateway_id, status, total_packets, unique_devices, start_time, end_time, created_at, updated_at
        )
        SELECT 
            id, session_name, gateway_id, status, total_packets, unique_devices, start_time, end_time, created_at, updated_at
        FROM lorawan_chirpstack.gateway_test_sessions
        ON CONFLICT (id) DO NOTHING;
    END IF;

    -- Migrate from system_schema.testing_packets if base table exists
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'system_schema' AND table_name = 'testing_packets'
        AND table_type = 'BASE TABLE'
    ) THEN
        INSERT INTO devices.device_packets (
            id, dev_eui, session_id, f_port, f_cnt, rssi, snr, frequency, payload_raw, payload_decoded, received_at, created_at
        )
        SELECT 
            id, dev_eui, session_id, f_port, f_cnt, rssi, snr, frequency, payload_raw, payload_decoded, received_at, created_at
        FROM system_schema.testing_packets
        ON CONFLICT (id) DO NOTHING;
    END IF;
END $$;

-- 5. Compatibility Views inside devices schema
CREATE OR REPLACE VIEW devices.testing_devices AS SELECT * FROM devices.devices;
CREATE OR REPLACE VIEW devices.testing_packets AS SELECT * FROM devices.device_packets;

-- 6. Backward Compatibility Views in system_schema and lorawan_chirpstack
DO $$
BEGIN
    -- system_schema compatibility
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'system_schema') THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'system_schema' AND table_name = 'testing_packets'
            AND table_type = 'BASE TABLE'
        ) THEN
            DROP TABLE IF EXISTS system_schema.testing_packets CASCADE;
        END IF;

        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'system_schema' AND table_name = 'testing_devices'
            AND table_type = 'BASE TABLE'
        ) THEN
            DROP TABLE IF EXISTS system_schema.testing_devices CASCADE;
        END IF;

        EXECUTE 'CREATE OR REPLACE VIEW system_schema.devices AS SELECT * FROM devices.devices';
        EXECUTE 'CREATE OR REPLACE VIEW system_schema.device_packets AS SELECT * FROM devices.device_packets';
        EXECUTE 'CREATE OR REPLACE VIEW system_schema.testing_devices AS SELECT * FROM devices.devices';
        EXECUTE 'CREATE OR REPLACE VIEW system_schema.testing_packets AS SELECT * FROM devices.device_packets';
    END IF;

    -- lorawan_chirpstack compatibility
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'lorawan_chirpstack') THEN
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions'
            AND table_type = 'BASE TABLE'
        ) THEN
            DROP TABLE IF EXISTS lorawan_chirpstack.gateway_test_sessions CASCADE;
        END IF;

        EXECUTE 'CREATE OR REPLACE VIEW lorawan_chirpstack.gateway_test_sessions AS SELECT * FROM devices.gateway_test_sessions';
    END IF;
END $$;

-- 7. Idempotent Runtime Grants
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
        GRANT USAGE, CREATE ON SCHEMA devices TO itest_system_user;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA devices TO itest_system_user;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA devices TO itest_system_user;
        GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA devices TO itest_system_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA devices GRANT ALL PRIVILEGES ON TABLES TO itest_system_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA devices GRANT ALL PRIVILEGES ON SEQUENCES TO itest_system_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA devices GRANT ALL PRIVILEGES ON ROUTINES TO itest_system_user;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
        GRANT USAGE ON SCHEMA devices TO itest_plugins_user;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA devices TO itest_plugins_user;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA devices TO itest_plugins_user;
        GRANT ALL PRIVILEGES ON ALL ROUTINES IN SCHEMA devices TO itest_plugins_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA devices GRANT ALL PRIVILEGES ON TABLES TO itest_plugins_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA devices GRANT ALL PRIVILEGES ON SEQUENCES TO itest_plugins_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA devices GRANT ALL PRIVILEGES ON ROUTINES TO itest_plugins_user;
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
        GRANT USAGE ON SCHEMA devices TO itest_ops_user;
        GRANT SELECT ON ALL TABLES IN SCHEMA devices TO itest_ops_user;
        ALTER DEFAULT PRIVILEGES IN SCHEMA devices GRANT SELECT ON TABLES TO itest_ops_user;
    END IF;
END $$;
