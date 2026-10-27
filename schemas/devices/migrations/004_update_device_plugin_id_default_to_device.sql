-- ==============================================================================
-- MIGRATION: 004_update_device_plugin_id_default_to_device.sql
-- Description:
--   1. Update default plugin_id in devices.devices to 'device' (independent from 'testing')
--   2. Update sync_device_serial_and_deveui trigger function to use 'device' default
--   3. Backfill existing records with plugin_id = 'testing' to 'device'
--   4. Refresh compatibility views (devices.testing_devices, system_schema.testing_devices)
--   5. Grant runtime privileges
-- Schema: devices, system_schema
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

-- 1. Alter Column Default and Backfill
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'devices' AND table_name = 'devices' AND column_name = 'plugin_id'
    ) THEN
        ALTER TABLE devices.devices ALTER COLUMN plugin_id SET DEFAULT 'device';
        
        -- Backfill existing records
        UPDATE devices.devices
        SET plugin_id = 'device'
        WHERE plugin_id = 'testing' OR plugin_id IS NULL;
    END IF;
END $$;

-- 2. Update Trigger Function to default to 'device'
CREATE OR REPLACE FUNCTION devices.sync_device_serial_and_deveui()
RETURNS TRIGGER AS $$
BEGIN
    -- Sync serial_number and dev_eui bidirectionally if one is empty
    IF (NEW.serial_number IS NULL OR TRIM(NEW.serial_number) = '') AND (NEW.dev_eui IS NOT NULL AND TRIM(NEW.dev_eui) <> '') THEN
        NEW.serial_number = NEW.dev_eui;
    ELSIF (NEW.dev_eui IS NULL OR TRIM(NEW.dev_eui) = '') AND (NEW.serial_number IS NOT NULL AND TRIM(NEW.serial_number) <> '') THEN
        NEW.dev_eui = NEW.serial_number;
    END IF;

    -- Default values
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

-- 3. Refresh Compatibility Views
DROP VIEW IF EXISTS devices.testing_devices CASCADE;
CREATE VIEW devices.testing_devices AS SELECT * FROM devices.devices;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'system_schema') THEN
        DROP VIEW IF EXISTS system_schema.devices CASCADE;
        CREATE VIEW system_schema.devices AS SELECT * FROM devices.devices;

        DROP VIEW IF EXISTS system_schema.testing_devices CASCADE;
        CREATE VIEW system_schema.testing_devices AS SELECT * FROM devices.devices;

        GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema.devices TO itest_system_user, itest_plugins_user, itest_admin;
        GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema.testing_devices TO itest_system_user, itest_plugins_user, itest_admin;
    END IF;
END $$;

-- 4. Grant runtime privileges
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON devices.devices TO itest_system_user;
        GRANT SELECT, INSERT, UPDATE, DELETE ON devices.testing_devices TO itest_system_user;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
        GRANT SELECT, INSERT, UPDATE, DELETE ON devices.devices TO itest_plugins_user;
        GRANT SELECT, INSERT, UPDATE, DELETE ON devices.testing_devices TO itest_plugins_user;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_admin') THEN
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA devices TO itest_admin;
    END IF;
END $$;
