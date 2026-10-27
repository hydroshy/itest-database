-- ==============================================================================
-- MIGRATION: 003_add_device_serial_number_and_traceability_columns.sql
-- Description: Add serial_number, network_id, device_name, device_type, plugin_id,
--              so_id, so_number, wa_id, wa_number, item_code to devices.devices.
--              Includes bidirectional sync trigger (serial_number <-> dev_eui),
--              indexes, backfilling, and refreshing compatibility views.
-- Schema: devices
-- Idempotency: Fully safe to re-run on existing PostgreSQL databases.
-- ==============================================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'devices' AND table_name = 'devices'
    ) THEN
        -- 0. Drop dependent views first to prevent any view dependency/locking errors during column alterations
        IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'system_schema') THEN
            DROP VIEW IF EXISTS system_schema.devices CASCADE;
            DROP VIEW IF EXISTS system_schema.testing_devices CASCADE;
        END IF;
        IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'devices') THEN
            DROP VIEW IF EXISTS devices.testing_devices CASCADE;
        END IF;

        -- 1. Add missing columns
        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'serial_number'
        ) THEN
            ALTER TABLE devices.devices ADD COLUMN serial_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'network_id'
        ) THEN
            ALTER TABLE devices.devices ADD COLUMN network_id VARCHAR(100);
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'device_name'
        ) THEN
            ALTER TABLE devices.devices ADD COLUMN device_name VARCHAR(255) DEFAULT 'Device';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'device_type'
        ) THEN
            ALTER TABLE devices.devices ADD COLUMN device_type VARCHAR(100) DEFAULT 'end_device';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'plugin_id'
        ) THEN
            ALTER TABLE devices.devices ADD COLUMN plugin_id VARCHAR(128) DEFAULT 'testing';
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'so_id'
        ) THEN
            ALTER TABLE devices.devices ADD COLUMN so_id UUID;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'so_number'
        ) THEN
            ALTER TABLE devices.devices ADD COLUMN so_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'wa_id'
        ) THEN
            ALTER TABLE devices.devices ADD COLUMN wa_id UUID;
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'wa_number'
        ) THEN
            ALTER TABLE devices.devices ADD COLUMN wa_number VARCHAR(100);
        END IF;

        IF NOT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'item_code'
        ) THEN
            ALTER TABLE devices.devices ADD COLUMN item_code VARCHAR(100);
        END IF;

        -- 2. Relax NOT NULL on dev_eui so entities without dev_eui can insert,
        -- trigger will ensure dev_eui <-> serial_number are synced.
        ALTER TABLE devices.devices ALTER COLUMN dev_eui DROP NOT NULL;

        -- 3. Backfill data
        UPDATE devices.devices
        SET
            serial_number = COALESCE(NULLIF(TRIM(serial_number), ''), dev_eui),
            dev_eui = COALESCE(NULLIF(TRIM(dev_eui), ''), serial_number),
            device_type = COALESCE(NULLIF(TRIM(device_type), ''), 'end_device'),
            plugin_id = COALESCE(NULLIF(TRIM(plugin_id), ''), 'testing'),
            device_name = COALESCE(NULLIF(TRIM(device_name), ''), 'Device ' || COALESCE(serial_number, dev_eui, id::text))
        WHERE serial_number IS NULL OR dev_eui IS NULL OR device_type IS NULL OR plugin_id IS NULL OR device_name IS NULL;
    END IF;
END $$;

-- 4. Bidirectional Trigger for serial_number <-> dev_eui and defaults
CREATE OR REPLACE FUNCTION devices.sync_device_serial_and_deveui()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync serial_number and dev_eui
    IF (NEW.serial_number IS NULL OR TRIM(NEW.serial_number) = '') AND (NEW.dev_eui IS NOT NULL AND TRIM(NEW.dev_eui) <> '') THEN
        NEW.serial_number = NEW.dev_eui;
    ELSIF (NEW.dev_eui IS NULL OR TRIM(NEW.dev_eui) = '') AND (NEW.serial_number IS NOT NULL AND TRIM(NEW.serial_number) <> '') THEN
        NEW.dev_eui = NEW.serial_number;
    END IF;

    -- Defaults
    IF NEW.device_type IS NULL OR TRIM(NEW.device_type) = '' THEN
        NEW.device_type = 'end_device';
    END IF;
    IF NEW.plugin_id IS NULL OR TRIM(NEW.plugin_id) = '' THEN
        NEW.plugin_id = 'testing';
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

-- 5. Indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_serial_number ON devices.devices(serial_number) WHERE serial_number IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_devices_network_id ON devices.devices(network_id);
CREATE INDEX IF NOT EXISTS idx_devices_device_type ON devices.devices(device_type);
CREATE INDEX IF NOT EXISTS idx_devices_plugin_id ON devices.devices(plugin_id);
CREATE INDEX IF NOT EXISTS idx_devices_so_id ON devices.devices(so_id);
CREATE INDEX IF NOT EXISTS idx_devices_so_number ON devices.devices(so_number);
CREATE INDEX IF NOT EXISTS idx_devices_wa_id ON devices.devices(wa_id);
CREATE INDEX IF NOT EXISTS idx_devices_wa_number ON devices.devices(wa_number);
CREATE INDEX IF NOT EXISTS idx_devices_item_code ON devices.devices(item_code);

-- 6. Refresh Compatibility Views
DROP VIEW IF EXISTS devices.testing_devices CASCADE;
CREATE VIEW devices.testing_devices AS SELECT * FROM devices.devices;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'system_schema') THEN
        DROP VIEW IF EXISTS system_schema.devices CASCADE;
        CREATE VIEW system_schema.devices AS SELECT * FROM devices.devices;

        DROP VIEW IF EXISTS system_schema.testing_devices CASCADE;
        CREATE VIEW system_schema.testing_devices AS SELECT * FROM devices.devices;

        GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema.devices TO itest_system_user, itest_plugins_user;
        GRANT SELECT ON system_schema.devices TO itest_ops_user;
        GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema.testing_devices TO itest_system_user, itest_plugins_user;
        GRANT SELECT ON system_schema.testing_devices TO itest_ops_user;
    END IF;
END $$;

-- 7. Grant Permissions to Runtime Roles
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE devices.devices TO itest_system_user, itest_plugins_user;
GRANT SELECT ON TABLE devices.devices TO itest_ops_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON devices.testing_devices TO itest_system_user, itest_plugins_user;
GRANT SELECT ON devices.testing_devices TO itest_ops_user;
