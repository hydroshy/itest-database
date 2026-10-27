-- ==============================================================================
-- MIGRATION: 004_extend_gateway_test_sessions_metadata.sql
-- Module: lorawan-chirpstack
-- Schema: lorawan_chirpstack
-- Description:
--   1. Extend gateway_test_sessions with Gateway Testing registration & traceability metadata:
--      so_number, wa_number, serial_number, eui, item_code, sku, gateway_notes,
--      hardware_version, firmware_version, mechanical_version,
--      lte_module_serial_number, lte_module_imei,
--      gateway_ip, internet_test_type, region_test, network_server_id,
--      lorawan_frequency_plan, config_snapshot, forwarder_config.
--   2. Maintain dual-schema compatibility between devices and lorawan_chirpstack.
--   3. Create view v_gateway_test_sessions_detail linking network_servers.
--   4. Grant runtime privileges across all application roles.
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO lorawan_chirpstack, public;

-- Drop dependent views first to avoid view column dependency rules during table modification
DROP VIEW IF EXISTS lorawan_chirpstack.v_gateway_test_sessions_detail CASCADE;
DROP VIEW IF EXISTS lorawan_chirpstack.gateway_test_sessions CASCADE;

DO $$
BEGIN
    -- Scenario A: devices.gateway_test_sessions is the base table
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions'
        AND table_type = 'BASE TABLE'
    ) THEN
        -- Add metadata columns to devices.gateway_test_sessions if missing
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

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'hardware_version') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN hardware_version VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'firmware_version') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN firmware_version VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'mechanical_version') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN mechanical_version VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'lte_module_serial_number') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN lte_module_serial_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'lte_module_imei') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN lte_module_imei VARCHAR(100);
        END IF;

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

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'config_snapshot') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN config_snapshot JSONB DEFAULT '{}'::jsonb;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'devices' AND table_name = 'gateway_test_sessions' AND column_name = 'forwarder_config') THEN
            ALTER TABLE devices.gateway_test_sessions ADD COLUMN forwarder_config JSONB DEFAULT '{}'::jsonb;
        END IF;

        ALTER TABLE devices.gateway_test_sessions ALTER COLUMN status SET DEFAULT 'REGISTERED';
        ALTER TABLE devices.gateway_test_sessions ALTER COLUMN session_name DROP NOT NULL;
        ALTER TABLE devices.gateway_test_sessions DROP CONSTRAINT IF EXISTS gateway_test_sessions_status_check;

        -- Recreate compatibility view
        DROP VIEW IF EXISTS lorawan_chirpstack.gateway_test_sessions CASCADE;
        EXECUTE 'CREATE OR REPLACE VIEW lorawan_chirpstack.gateway_test_sessions AS SELECT * FROM devices.gateway_test_sessions';

    -- Scenario B: lorawan_chirpstack.gateway_test_sessions is a base table
    ELSIF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions'
        AND table_type = 'BASE TABLE'
    ) THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'so_number') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN so_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'wa_number') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN wa_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'serial_number') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN serial_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'eui') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN eui VARCHAR(64);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'item_code') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN item_code VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'sku') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN sku VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'gateway_notes') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN gateway_notes TEXT;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'hardware_version') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN hardware_version VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'firmware_version') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN firmware_version VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'mechanical_version') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN mechanical_version VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'lte_module_serial_number') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN lte_module_serial_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'lte_module_imei') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN lte_module_imei VARCHAR(100);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'gateway_ip') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN gateway_ip VARCHAR(45);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'internet_test_type') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN internet_test_type VARCHAR(20) DEFAULT 'ETHERNET';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'region_test') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN region_test VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'network_server_id') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN network_server_id UUID;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'lorawan_frequency_plan') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN lorawan_frequency_plan VARCHAR(50);
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'config_snapshot') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN config_snapshot JSONB DEFAULT '{}'::jsonb;
        END IF;

        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'lorawan_chirpstack' AND table_name = 'gateway_test_sessions' AND column_name = 'forwarder_config') THEN
            ALTER TABLE lorawan_chirpstack.gateway_test_sessions ADD COLUMN forwarder_config JSONB DEFAULT '{}'::jsonb;
        END IF;

        ALTER TABLE lorawan_chirpstack.gateway_test_sessions ALTER COLUMN status SET DEFAULT 'REGISTERED';
        ALTER TABLE lorawan_chirpstack.gateway_test_sessions ALTER COLUMN session_name DROP NOT NULL;

        -- Create indexes
        CREATE INDEX IF NOT EXISTS idx_lorawan_gw_sessions_serial_number ON lorawan_chirpstack.gateway_test_sessions(serial_number);
        CREATE INDEX IF NOT EXISTS idx_lorawan_gw_sessions_eui ON lorawan_chirpstack.gateway_test_sessions(eui);
        CREATE INDEX IF NOT EXISTS idx_lorawan_gw_sessions_so_number ON lorawan_chirpstack.gateway_test_sessions(so_number);
        CREATE INDEX IF NOT EXISTS idx_lorawan_gw_sessions_wa_number ON lorawan_chirpstack.gateway_test_sessions(wa_number);
        CREATE INDEX IF NOT EXISTS idx_lorawan_gw_sessions_gateway_ip ON lorawan_chirpstack.gateway_test_sessions(gateway_ip);
        CREATE INDEX IF NOT EXISTS idx_lorawan_gw_sessions_network_server_id ON lorawan_chirpstack.gateway_test_sessions(network_server_id);
    END IF;
END $$;

-- 2. Detail View: v_gateway_test_sessions_detail
DROP VIEW IF EXISTS lorawan_chirpstack.v_gateway_test_sessions_detail CASCADE;

CREATE OR REPLACE VIEW lorawan_chirpstack.v_gateway_test_sessions_detail AS
SELECT 
    s.id,
    s.session_name,
    s.gateway_id,
    s.gateway_name,
    s.status,
    s.so_number,
    s.wa_number,
    s.serial_number,
    s.eui,
    s.item_code,
    s.sku,
    s.gateway_notes,
    s.hardware_version,
    s.firmware_version,
    s.mechanical_version,
    s.lte_module_serial_number,
    s.lte_module_imei,
    s.gateway_ip,
    s.internet_test_type,
    s.region_test,
    s.network_server_id,
    ns.name AS network_server_name,
    ns.api_url AS network_server_url,
    ns.tenant_id AS network_server_tenant_id,
    s.lorawan_frequency_plan,
    s.config_snapshot,
    s.forwarder_config,
    s.summary,
    s.started_at,
    s.ended_at,
    s.created_at,
    s.updated_at
FROM lorawan_chirpstack.gateway_test_sessions s
LEFT JOIN lorawan_chirpstack.network_servers ns ON s.network_server_id = ns.id;

COMMENT ON VIEW lorawan_chirpstack.v_gateway_test_sessions_detail IS 'View chi tiết phiên kiểm thử Gateway bao gồm metadata cấu hình 4050 và thông tin Network Server ChirpStack';

-- 3. Grant Privileges
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lorawan_chirpstack TO itest_system_user;
        GRANT SELECT ON lorawan_chirpstack.v_gateway_test_sessions_detail TO itest_system_user;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lorawan_chirpstack TO itest_plugins_user;
        GRANT SELECT ON lorawan_chirpstack.v_gateway_test_sessions_detail TO itest_plugins_user;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lorawan_chirpstack TO itest_ops_user;
        GRANT SELECT ON lorawan_chirpstack.v_gateway_test_sessions_detail TO itest_ops_user;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_user') THEN
        GRANT SELECT ON ALL TABLES IN SCHEMA lorawan_chirpstack TO itest_user;
        GRANT SELECT ON lorawan_chirpstack.v_gateway_test_sessions_detail TO itest_user;
    END IF;
END $$;
