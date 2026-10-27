-- ==============================================================================
-- MIGRATION: 005_extend_gateway_test_sessions_metadata.sql
-- Description:
--   1. Add Gateway Testing traceability metadata columns to devices.gateway_test_sessions:
--      so_number, wa_number, serial_number, eui, item_code, sku, gateway_notes,
--      hardware_version, firmware_version, mechanical_version,
--      lte_module_serial_number, lte_module_imei,
--      gateway_ip, internet_test_type, region_test, network_server_id,
--      lorawan_frequency_plan, config_snapshot, forwarder_config.
--   2. Adjust status and session_name constraints for Gateway Testing workflows.
--   3. Create indexes for quick lookup by serial, eui, so/wa, item_code, ip, network_server.
--   4. Update sync_gateway_test_sessions_columns trigger for eui <-> gateway_id.
--   5. Refresh compatibility views across devices and lorawan_chirpstack schemas.
--   6. Grant runtime privileges to all application roles.
-- Schema: devices, lorawan_chirpstack
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions'
    ) THEN
        -- Traceability columns
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'so_number') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN so_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'wa_number') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN wa_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'serial_number') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN serial_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'eui') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN eui VARCHAR(64);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'item_code') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN item_code VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'sku') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN sku VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'gateway_notes') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN gateway_notes TEXT;
        END IF;

        -- Hardware & Version columns
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'hardware_version') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN hardware_version VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'firmware_version') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN firmware_version VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'mechanical_version') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN mechanical_version VARCHAR(50);
        END IF;

        -- LTE Module columns
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'lte_module_serial_number') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN lte_module_serial_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'lte_module_imei') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN lte_module_imei VARCHAR(100);
        END IF;

        -- Network & Testing parameters
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'gateway_ip') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN gateway_ip VARCHAR(45);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'internet_test_type') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN internet_test_type VARCHAR(20) DEFAULT 'ETHERNET';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'region_test') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN region_test VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'network_server_id') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN network_server_id UUID;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'lorawan_frequency_plan') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN lorawan_frequency_plan VARCHAR(50);
        END IF;

        -- JSONB Config and Snapshot
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'config_snapshot') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN config_snapshot JSONB DEFAULT '{}'::jsonb;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'forwarder_config') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN forwarder_config JSONB DEFAULT '{}'::jsonb;
        END IF;

        -- Relax status constraint & session_name length
        ALTER TABLE devices.gateway_test_sessions ALTER COLUMN status TYPE VARCHAR(50);
        ALTER TABLE devices.gateway_test_sessions ALTER COLUMN status SET DEFAULT 'REGISTERED';
        ALTER TABLE devices.gateway_test_sessions ALTER COLUMN session_name TYPE VARCHAR(255);
        ALTER TABLE devices.gateway_test_sessions ALTER COLUMN session_name DROP NOT NULL;
        ALTER TABLE devices.gateway_test_sessions DROP CONSTRAINT IF EXISTS gateway_test_sessions_status_check;

        -- Backfill eui from gateway_id if eui is null
        UPDATE devices.gateway_test_sessions
        SET eui = gateway_id
        WHERE eui IS NULL AND gateway_id IS NOT NULL;
    END IF;
END $$;

-- 2. Create Indexes
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_serial_number ON devices.gateway_test_sessions(serial_number);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_eui ON devices.gateway_test_sessions(eui);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_so_number ON devices.gateway_test_sessions(so_number);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_wa_number ON devices.gateway_test_sessions(wa_number);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_item_code ON devices.gateway_test_sessions(item_code);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_gateway_ip ON devices.gateway_test_sessions(gateway_ip);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_network_server_id ON devices.gateway_test_sessions(network_server_id);
CREATE INDEX IF NOT EXISTS idx_devices_gw_sessions_config_snapshot_gin ON devices.gateway_test_sessions USING GIN (config_snapshot);

-- 3. Enhance Synchronization Trigger for Gateway Sessions
CREATE OR REPLACE FUNCTION devices.sync_gateway_test_sessions_columns()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync gateway_id and eui bidirectionally
    IF NEW.eui IS NULL AND NEW.gateway_id IS NOT NULL THEN
        NEW.eui = NEW.gateway_id;
    ELSIF NEW.gateway_id IS NULL AND NEW.eui IS NOT NULL THEN
        NEW.gateway_id = NEW.eui;
    END IF;

    -- Sync gateway_name
    IF NEW.gateway_name IS NULL AND NEW.gateway_id IS NOT NULL THEN
        NEW.gateway_name = NEW.gateway_id;
    END IF;

    -- Sync session_name if null
    IF NEW.session_name IS NULL THEN
        NEW.session_name = 'GW-' || COALESCE(NEW.serial_number, NEW.gateway_id, 'SESSION');
    END IF;

    -- Sync timestamps
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

-- 4. Recreate Compatibility View in lorawan_chirpstack schema
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'lorawan_chirpstack') THEN
        DROP VIEW IF EXISTS lorawan_chirpstack.gateway_test_sessions CASCADE;
        EXECUTE 'CREATE OR REPLACE VIEW lorawan_chirpstack.gateway_test_sessions AS SELECT * FROM devices.gateway_test_sessions';

        -- Detail view with network_servers join if network_servers table exists
        IF EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'network_servers'
        ) THEN
            DROP VIEW IF EXISTS lorawan_chirpstack.v_gateway_test_sessions_detail CASCADE;
            EXECUTE 'CREATE OR REPLACE VIEW lorawan_chirpstack.v_gateway_test_sessions_detail AS
                SELECT 
                    s.*,
                    ns.name AS network_server_name,
                    ns.api_url AS network_server_url,
                    ns.tenant_id AS network_server_tenant_id
                FROM devices.gateway_test_sessions s
                LEFT JOIN lorawan_chirpstack.network_servers ns ON s.network_server_id = ns.id';
        END IF;
    END IF;
END $$;

-- 5. Grant Permissions
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON devices.gateway_test_sessions TO itest_system_user;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON devices.gateway_test_sessions TO itest_plugins_user;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON devices.gateway_test_sessions TO itest_ops_user;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_user') THEN
        GRANT SELECT ON devices.gateway_test_sessions TO itest_user;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'lorawan_chirpstack') THEN
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
            GRANT SELECT ON ALL TABLES IN SCHEMA lorawan_chirpstack TO itest_system_user;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
            GRANT SELECT ON ALL TABLES IN SCHEMA lorawan_chirpstack TO itest_plugins_user;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
            GRANT SELECT ON ALL TABLES IN SCHEMA lorawan_chirpstack TO itest_ops_user;
        END IF;
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_user') THEN
            GRANT SELECT ON ALL TABLES IN SCHEMA lorawan_chirpstack TO itest_user;
        END IF;
    END IF;
END $$;
