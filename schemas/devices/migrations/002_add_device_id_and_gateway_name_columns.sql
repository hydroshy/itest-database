-- ==============================================================================
-- MIGRATION: 002_add_device_id_and_gateway_name_columns.sql
-- Description: Add device_id, raw_payload, decoded_payload, rf_info, packet_type to
--              devices.device_packets and gateway_name, started_at, ended_at, summary
--              to devices.gateway_test_sessions.
--              Includes backfilling, trigger synchronization, and compatibility views.
-- Schema: devices
-- Idempotency: Fully safe to re-run on existing PostgreSQL databases.
-- ==============================================================================

-- 1. Enhance devices.gateway_test_sessions table
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions'
    ) THEN
        -- gateway_name
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'gateway_name'
        ) THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN gateway_name VARCHAR(255);
        END IF;

        -- started_at
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'started_at'
        ) THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP;
        END IF;

        -- ended_at
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'ended_at'
        ) THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN ended_at TIMESTAMPTZ;
        END IF;

        -- summary
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'summary'
        ) THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN summary JSONB DEFAULT '{}'::jsonb;
        END IF;

        -- Sync existing data: start_time -> started_at, end_time -> ended_at, gateway_id -> gateway_name if null
        UPDATE devices.gateway_test_sessions
        SET 
            gateway_name = COALESCE(gateway_name, session_name, gateway_id),
            started_at = COALESCE(started_at, start_time, created_at),
            ended_at = COALESCE(ended_at, end_time)
        WHERE gateway_name IS NULL OR started_at IS NULL;
    END IF;
END $$;

-- 2. Enhance devices.device_packets table
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables 
        WHERE table_schema = 'devices' AND table_name = 'device_packets'
    ) THEN
        -- device_id (UUID references devices.devices(id))
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'devices' AND table_name = 'device_packets' AND column_name = 'device_id'
        ) THEN
            ALTER TABLE devices.device_packets ADD COLUMN device_id UUID;
        END IF;

        -- packet_type
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'devices' AND table_name = 'device_packets' AND column_name = 'packet_type'
        ) THEN
            ALTER TABLE devices.device_packets ADD COLUMN packet_type VARCHAR(50) DEFAULT 'uplink';
        END IF;

        -- raw_payload
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'devices' AND table_name = 'device_packets' AND column_name = 'raw_payload'
        ) THEN
            ALTER TABLE devices.device_packets ADD COLUMN raw_payload TEXT;
        END IF;

        -- decoded_payload
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'devices' AND table_name = 'device_packets' AND column_name = 'decoded_payload'
        ) THEN
            ALTER TABLE devices.device_packets ADD COLUMN decoded_payload JSONB DEFAULT '{}'::jsonb;
        END IF;

        -- rf_info
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_schema = 'devices' AND table_name = 'device_packets' AND column_name = 'rf_info'
        ) THEN
            ALTER TABLE devices.device_packets ADD COLUMN rf_info JSONB DEFAULT '{}'::jsonb;
        END IF;

        -- Backfill raw_payload from payload_raw, decoded_payload from payload_decoded
        UPDATE devices.device_packets
        SET 
            raw_payload = COALESCE(raw_payload, payload_raw),
            decoded_payload = COALESCE(decoded_payload, payload_decoded, '{}'::jsonb),
            rf_info = CASE 
                WHEN rf_info IS NULL OR rf_info = '{}'::jsonb THEN
                    jsonb_build_object('rssi', rssi, 'snr', snr, 'frequency', frequency)
                ELSE rf_info
            END
        WHERE raw_payload IS NULL OR payload_raw IS NOT NULL;

        -- Backfill device_id by matching dev_eui against devices.devices
        UPDATE devices.device_packets p
        SET device_id = d.id
        FROM devices.devices d
        WHERE p.device_id IS NULL AND p.dev_eui = d.dev_eui;

        -- Backfill device_id from system_schema.devices if dev_eui matches serial_number
        IF EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_schema = 'system_schema' AND table_name = 'devices' AND table_type = 'BASE TABLE'
        ) THEN
            UPDATE devices.device_packets p
            SET device_id = sd.id
            FROM system_schema.devices sd
            WHERE p.device_id IS NULL AND (p.dev_eui = sd.serial_number OR p.dev_eui = sd.network_id);
        END IF;
    END IF;
END $$;

-- 3. Ensure Foreign Key and Indexes on devices.device_packets
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_schema = 'devices' AND constraint_name = 'fk_device_packets_device_id'
    ) THEN
        ALTER TABLE devices.device_packets
        ADD CONSTRAINT fk_device_packets_device_id
        FOREIGN KEY (device_id) REFERENCES devices.devices(id) ON DELETE SET NULL;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_device_packets_device_id ON devices.device_packets(device_id);
CREATE INDEX IF NOT EXISTS idx_device_packets_packet_type ON devices.device_packets(packet_type);
CREATE INDEX IF NOT EXISTS idx_device_packets_decoded_payload_gin ON devices.device_packets USING GIN (decoded_payload);
CREATE INDEX IF NOT EXISTS idx_device_packets_rf_info_gin ON devices.device_packets USING GIN (rf_info);
CREATE INDEX IF NOT EXISTS idx_gateway_test_sessions_gateway_name ON devices.gateway_test_sessions(gateway_name);

-- 4. Synchronization triggers to keep aliases in sync on INSERT/UPDATE
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

-- Trigger for gateway_test_sessions time & name sync
CREATE OR REPLACE FUNCTION devices.sync_gateway_test_sessions_columns()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.gateway_name IS NULL AND NEW.gateway_id IS NOT NULL THEN
        NEW.gateway_name = NEW.gateway_id;
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

-- 5. Re-create / Refresh Views to include new columns
CREATE OR REPLACE VIEW devices.testing_devices AS SELECT * FROM devices.devices;
CREATE OR REPLACE VIEW devices.testing_packets AS SELECT * FROM devices.device_packets;

-- Refresh compatibility views in system_schema if exists
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'system_schema') THEN
        CREATE OR REPLACE VIEW system_schema.device_packets AS SELECT * FROM devices.device_packets;
        CREATE OR REPLACE VIEW system_schema.testing_packets AS SELECT * FROM devices.device_packets;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'lorawan_chirpstack') THEN
        CREATE OR REPLACE VIEW lorawan_chirpstack.gateway_test_sessions AS SELECT * FROM devices.gateway_test_sessions;
    END IF;
END $$;
