-- ==============================================================================
-- SCHEMA SNAPSHOT: traceability_manager
-- Module: traceability-manager
-- Description: Complete consolidated baseline schema definition for Device Traceability.
--              Includes tables, relations, triggers, indexes, and Metabase views.
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS traceability_manager;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Migration ledger
CREATE TABLE IF NOT EXISTS traceability_manager."_migrations" (
  "id" SERIAL PRIMARY KEY,
  "migration_name" VARCHAR(255) NOT NULL UNIQUE,
  "batch" INTEGER NOT NULL DEFAULT 1,
  "applied_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "checksum" VARCHAR(64)
);

-- Trigger function
CREATE OR REPLACE FUNCTION traceability_manager.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. ERP Work Order Batch Table
CREATE TABLE IF NOT EXISTS traceability_manager."traceability_order" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "so_number" VARCHAR(50) NOT NULL,
  "wa_number" VARCHAR(50) NOT NULL,
  "item_code" VARCHAR(100) NOT NULL,
  "connectivity" VARCHAR(20) NOT NULL DEFAULT 'LoRaWAN',
  "total_quantity" INTEGER NOT NULL DEFAULT 0,
  "notes" TEXT,
  "created_by" VARCHAR(100) DEFAULT 'system',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "uq_traceability_order_so_wa_item" UNIQUE ("so_number", "wa_number", "item_code")
);

COMMENT ON TABLE traceability_manager."traceability_order" IS 'ERP Work Orders & Production Batches defining SO_NUMBER, WA_NUMBER, ITEM_CODE and connectivity type';
COMMENT ON COLUMN traceability_manager."traceability_order"."id" IS 'Primary Key UUID of the production order';
COMMENT ON COLUMN traceability_manager."traceability_order"."so_number" IS 'Sales Order Number from ERP (e.g. SO/2026/01850)';
COMMENT ON COLUMN traceability_manager."traceability_order"."wa_number" IS 'Work Authorization / Manufacturing Order Number (e.g. WA/2026/00412)';
COMMENT ON COLUMN traceability_manager."traceability_order"."item_code" IS 'Finished goods item code from ERP (e.g. WSLRW-ATH-11)';
COMMENT ON COLUMN traceability_manager."traceability_order"."connectivity" IS 'Physical wireless connectivity protocol: LoRaWAN, Sigfox, NB-IoT, Others';
COMMENT ON COLUMN traceability_manager."traceability_order"."total_quantity" IS 'Target manufacturing quantity for this work order';
COMMENT ON COLUMN traceability_manager."traceability_order"."created_by" IS 'Author / system username creating the work order';

DROP TRIGGER IF EXISTS trg_traceability_order_updated_at ON traceability_manager."traceability_order";
CREATE TRIGGER trg_traceability_order_updated_at
BEFORE UPDATE ON traceability_manager."traceability_order"
FOR EACH ROW
EXECUTE FUNCTION traceability_manager.set_current_timestamp_updated_at();

CREATE INDEX IF NOT EXISTS "idx_traceability_order_so_number" ON traceability_manager."traceability_order" ("so_number");
CREATE INDEX IF NOT EXISTS "idx_traceability_order_wa_number" ON traceability_manager."traceability_order" ("wa_number");
CREATE INDEX IF NOT EXISTS "idx_traceability_order_item_code" ON traceability_manager."traceability_order" ("item_code");
CREATE INDEX IF NOT EXISTS "idx_traceability_order_connectivity" ON traceability_manager."traceability_order" ("connectivity");
CREATE INDEX IF NOT EXISTS "idx_traceability_order_created_at" ON traceability_manager."traceability_order" ("created_at");

-- 2. Individual Device Units Table
CREATE TABLE IF NOT EXISTS traceability_manager."traceability_device" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "order_id" UUID NOT NULL REFERENCES traceability_manager."traceability_order"("id") ON DELETE CASCADE,
  "serial_number" VARCHAR(100) NOT NULL UNIQUE,
  "sku" VARCHAR(100) NOT NULL,
  "fw_version" VARCHAR(50) NOT NULL,
  "hw_version" VARCHAR(50),
  "me_version" VARCHAR(50),
  "dev_eui" VARCHAR(32),
  "app_eui" VARCHAR(32),
  "app_key" VARCHAR(64),
  "sigfox_id" VARCHAR(16),
  "sigfox_pac" VARCHAR(32),
  "telecom_credentials" JSONB DEFAULT '{}'::jsonb,
  "final_config_session_id" UUID,
  "config_status" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  "chirpstack_synced" BOOLEAN NOT NULL DEFAULT FALSE,
  "status" VARCHAR(30) NOT NULL DEFAULT 'INITIAL',
  "notes" TEXT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE traceability_manager."traceability_device" IS 'Individual manufactured devices with hardware revisions, wireless credentials, and manufacturing execution link';
COMMENT ON COLUMN traceability_manager."traceability_device"."id" IS 'Primary Key UUID of the device';
COMMENT ON COLUMN traceability_manager."traceability_device"."order_id" IS 'Foreign Key referencing traceability_order(id)';
COMMENT ON COLUMN traceability_manager."traceability_device"."serial_number" IS 'Unique physical serial number printed on label/enclosure (e.g. SN202610220001)';
COMMENT ON COLUMN traceability_manager."traceability_device"."sku" IS 'Product SKU code';
COMMENT ON COLUMN traceability_manager."traceability_device"."fw_version" IS 'Installed Firmware version (compatible with long_fw)';
COMMENT ON COLUMN traceability_manager."traceability_device"."hw_version" IS 'Hardware PCBA revision (e.g. HW1.2)';
COMMENT ON COLUMN traceability_manager."traceability_device"."me_version" IS 'Mechanical enclosure revision (e.g. ME1.0)';
COMMENT ON COLUMN traceability_manager."traceability_device"."dev_eui" IS 'LoRaWAN Device EUI (16 hex characters)';
COMMENT ON COLUMN traceability_manager."traceability_device"."app_eui" IS 'LoRaWAN JoinEUI / AppEUI (16 hex characters)';
COMMENT ON COLUMN traceability_manager."traceability_device"."app_key" IS 'LoRaWAN OTAA 128-bit Application Key (32 hex characters)';
COMMENT ON COLUMN traceability_manager."traceability_device"."sigfox_id" IS 'Sigfox Device ID (8 hex characters)';
COMMENT ON COLUMN traceability_manager."traceability_device"."sigfox_pac" IS 'Sigfox Initial Porting Access Code (16 hex characters)';
COMMENT ON COLUMN traceability_manager."traceability_device"."telecom_credentials" IS 'Flexible JSONB payload for cellular IMEI/IMSI, BLE MAC, or private keys';
COMMENT ON COLUMN traceability_manager."traceability_device"."final_config_session_id" IS 'Reference to finalconfig_manager.finalconfig_execution_session(id)';
COMMENT ON COLUMN traceability_manager."traceability_device"."config_status" IS 'Final configuration status: PENDING, CONFIGURED_PASS, CONFIGURED_FAIL';
COMMENT ON COLUMN traceability_manager."traceability_device"."chirpstack_synced" IS 'Flag indicating whether device credentials have been provisioned to Network Server';
COMMENT ON COLUMN traceability_manager."traceability_device"."status" IS 'Lifecycle stage: INITIAL, CONFIGURED, QA_PASSED, PACKED, SHIPPED';

DROP TRIGGER IF EXISTS trg_traceability_device_updated_at ON traceability_manager."traceability_device";
CREATE TRIGGER trg_traceability_device_updated_at
BEFORE UPDATE ON traceability_manager."traceability_device"
FOR EACH ROW
EXECUTE FUNCTION traceability_manager.set_current_timestamp_updated_at();

CREATE INDEX IF NOT EXISTS "idx_traceability_device_order_id" ON traceability_manager."traceability_device" ("order_id");
CREATE INDEX IF NOT EXISTS "idx_traceability_device_serial_number" ON traceability_manager."traceability_device" ("serial_number");
CREATE INDEX IF NOT EXISTS "idx_traceability_device_sku" ON traceability_manager."traceability_device" ("sku");
CREATE INDEX IF NOT EXISTS "idx_traceability_device_dev_eui" ON traceability_manager."traceability_device" ("dev_eui") WHERE "dev_eui" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_traceability_device_sigfox_id" ON traceability_manager."traceability_device" ("sigfox_id") WHERE "sigfox_id" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_traceability_device_final_config_session_id" ON traceability_manager."traceability_device" ("final_config_session_id") WHERE "final_config_session_id" IS NOT NULL;
CREATE INDEX IF NOT EXISTS "idx_traceability_device_config_status" ON traceability_manager."traceability_device" ("config_status");
CREATE INDEX IF NOT EXISTS "idx_traceability_device_status" ON traceability_manager."traceability_device" ("status");
CREATE INDEX IF NOT EXISTS "idx_traceability_device_created_at" ON traceability_manager."traceability_device" ("created_at");

-- 3. Analytical BI View for Metabase
CREATE OR REPLACE VIEW traceability_manager.v_device_traceability_lifecycle AS
SELECT
    d.id AS device_id,
    d.serial_number,
    o.so_number,
    o.wa_number,
    o.item_code,
    o.connectivity,
    d.sku,
    d.fw_version,
    d.hw_version,
    d.me_version,
    d.dev_eui,
    d.app_eui,
    d.sigfox_id,
    d.config_status,
    d.chirpstack_synced,
    d.status AS device_status,
    d.final_config_session_id,
    fcs.status AS final_config_session_status,
    fcs.serial_number AS final_config_device_sn,
    fcs.passed_steps AS config_passed_steps,
    fcs.failed_steps AS config_failed_steps,
    fcs.total_steps AS config_total_steps,
    fcs.completed_at AS configured_at,
    d.created_at AS device_created_at,
    o.created_at AS order_created_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_order o ON d.order_id = o.id
LEFT JOIN finalconfig_manager.finalconfig_execution_session fcs ON d.final_config_session_id = fcs.id;

COMMENT ON VIEW traceability_manager.v_device_traceability_lifecycle IS 'Comprehensive analytical Metabase view linking ERP Orders, Device Credentials, and Final Config QA Execution metrics';
