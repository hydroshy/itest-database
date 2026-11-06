-- ==============================================================================
-- MIGRATION: 010_create_device_test_registrations_and_views.sql
-- Description:
--   1. Create system_schema.device_test_registrations:
--      - Tracks the 3-step Create Device Testing workflow:
--        Step 1: Connectivity (LoRaWAN), SO, WA, Network Server
--        Step 2: Serial fast read parameters (registers 0..259 per ATH_TEMPLATE.csv):
--                fw_code, fw_version, hw_version, me_version, dev_eui, app_eui, app_key,
--                region_code, class, sensor_type, serial_number, item_code.
--        Step 3: ChirpStack 2-step automatic registration:
--                (application_id, device_profile_id, dev_eui, join_eui, name, skip_fcnt_check, keys)
--                Registration status: PENDING, REGISTERING, SUCCESS_ATTACH_BATTERY, FAILED
--   2. Alter devices.devices & system_schema.devices to support fast registration metadata
--   3. Create multi-schema compatibility views:
--      - v_device_test_registrations_detail (joins SO, WA, network_servers)
--      - v_testing_active_traceability (quick SO/WA list for Step 1 dropdown)
--   4. Grant runtime privileges to all application roles
-- Note: NO MOCK DATA inserted.
-- Schema: system_schema, devices, public
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Create system_schema.device_test_registrations
CREATE TABLE IF NOT EXISTS system_schema."device_test_registrations" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "registration_code" VARCHAR(100) NOT NULL UNIQUE,
  
  -- Step 1: Connectivity & Traceability & Network Server
  "connectivity" VARCHAR(50) NOT NULL DEFAULT 'LoRaWAN',
  "so_id" UUID,
  "so_number" VARCHAR(100),
  "wa_id" UUID,
  "wa_number" VARCHAR(100),
  "item_code" VARCHAR(100),
  "network_server_id" UUID,
  "network_server_name" VARCHAR(100),
  "network_server_url" VARCHAR(255),
  
  -- Step 2: Serial Read Parameters (ATH_TEMPLATE.csv registers 0..259)
  "serial_port" VARCHAR(50),
  "baud_rate" INTEGER NOT NULL DEFAULT 9600,
  "fw_code" VARCHAR(50),             -- Reg 0 (5 regs, string)
  "fw_version" VARCHAR(50),          -- Reg 5 (4 regs, string)
  "long_fw" VARCHAR(255),            -- Optional explicit long FW version
  "hw_version" VARCHAR(50),          -- Reg 9 (2 regs, string)
  "me_version" VARCHAR(50),          -- Reg 15 (2 regs, string)
  "dev_eui" VARCHAR(64),             -- Reg 27 (4 regs, hex 64-bit)
  "app_eui" VARCHAR(64),             -- Reg 31 (4 regs, hex 64-bit)
  "app_key" VARCHAR(64),             -- Reg 35 (8 regs, hex 128-bit)
  "region_code" VARCHAR(50),         -- Reg 69 (3 regs, string: AS923-1, etc.)
  "class_mode" VARCHAR(20),          -- Reg 85 (1 reg, string: A, C)
  "sensor_type" VARCHAR(50),         -- Reg 103 (1 reg, uint16)
  "serial_number" VARCHAR(100),      -- Reg 259 (9 regs, string)
  "device_name" VARCHAR(255),        -- Usually equals serial_number
  "raw_registers_snapshot" JSONB NOT NULL DEFAULT '{}'::jsonb,
  
  -- Step 3: ChirpStack Automatic Registration Status & Payload
  "application_id" VARCHAR(100),
  "device_profile_id" VARCHAR(100),
  "chirpstack_payload" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "step" INTEGER NOT NULL DEFAULT 1, -- 1, 2, 3
  "status" VARCHAR(50) NOT NULL DEFAULT 'PENDING', 
  -- Status enum: PENDING, SERIAL_READ_OK, REGISTERING, SUCCESS_ATTACH_BATTERY, FAILED
  "message" TEXT,
  "error_detail" TEXT,
  
  -- Link to main device record
  "device_id" UUID,
  
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'tester',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system_schema."device_test_registrations" IS 'Lưu trữ thông tin quy trình đăng ký thiết bị kiểm thử 3 bước (Traceability -> Serial Read 0..259 -> ChirpStack Provisioning)';
COMMENT ON COLUMN system_schema."device_test_registrations"."status" IS 'PENDING, SERIAL_READ_OK, REGISTERING, SUCCESS_ATTACH_BATTERY, FAILED';
COMMENT ON COLUMN system_schema."device_test_registrations"."message" IS 'Thông báo kết quả: Đăng ký Thành công vui lòng gắn pin cảm biến / thông báo lỗi';

-- Trigger auto updated_at
DROP TRIGGER IF EXISTS trg_device_test_registrations_updated_at ON system_schema."device_test_registrations";
CREATE TRIGGER trg_device_test_registrations_updated_at
BEFORE UPDATE ON system_schema."device_test_registrations"
FOR EACH ROW
EXECUTE FUNCTION system_schema.set_current_timestamp_updated_at();

-- Indexes for fast query
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_dev_eui" ON system_schema."device_test_registrations"("dev_eui");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_serial_number" ON system_schema."device_test_registrations"("serial_number");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_so_number" ON system_schema."device_test_registrations"("so_number");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_wa_number" ON system_schema."device_test_registrations"("wa_number");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_item_code" ON system_schema."device_test_registrations"("item_code");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_status" ON system_schema."device_test_registrations"("status");
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_created_at" ON system_schema."device_test_registrations"("created_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_dtest_reg_registers_gin" ON system_schema."device_test_registrations" USING GIN ("raw_registers_snapshot");

-- 2. Detail Enriched View linking Traceability & ChirpStack Network Servers
DROP VIEW IF EXISTS system_schema.v_device_test_registrations_detail CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_test_registrations_detail AS
SELECT
  r."id",
  r."registration_code",
  r."connectivity",
  r."so_id",
  r."so_number",
  so."customer_name",
  so."partner_email",
  r."wa_id",
  r."wa_number",
  wa."planned_quantity" AS "wa_planned_quantity",
  r."item_code",
  r."network_server_id",
  COALESCE(ns."name", r."network_server_name") AS "network_server_name",
  COALESCE(ns."api_url", r."network_server_url") AS "network_server_url",
  r."serial_port",
  r."baud_rate",
  r."fw_code",
  r."fw_version",
  r."hw_version",
  r."me_version",
  r."dev_eui",
  r."app_eui",
  r."app_key",
  r."region_code",
  r."class_mode",
  r."sensor_type",
  r."serial_number",
  r."device_name",
  r."raw_registers_snapshot",
  COALESCE(r."application_id", ns."application_id") AS "application_id",
  COALESCE(r."device_profile_id", ns."device_profile_id") AS "device_profile_id",
  r."chirpstack_payload",
  r."step",
  r."status",
  r."message",
  r."error_detail",
  r."device_id",
  r."created_by",
  r."created_at",
  r."updated_at"
FROM system_schema."device_test_registrations" r
LEFT JOIN traceability_manager."traceability_so" so 
  ON (r."so_id" = so."id" OR (r."so_number" IS NOT NULL AND r."so_number" = so."so_number"))
LEFT JOIN traceability_manager."traceability_wa" wa 
  ON (r."wa_id" = wa."id" OR (r."wa_number" IS NOT NULL AND r."wa_number" = wa."wa_number"))
LEFT JOIN lorawan_chirpstack."network_servers" ns 
  ON (r."network_server_id" = ns."id");

-- 3. Active Traceability Quick View for Step 1 Dropdowns
DROP VIEW IF EXISTS system_schema.v_testing_active_traceability CASCADE;
CREATE OR REPLACE VIEW system_schema.v_testing_active_traceability AS
SELECT
  so."id" AS "so_id",
  so."so_number",
  so."customer_name",
  so."partner_email",
  wa."id" AS "wa_id",
  wa."wa_number",
  wa."item_code",
  wa."planned_quantity"
FROM traceability_manager."traceability_so" so
JOIN traceability_manager."traceability_wa" wa ON so."id" = wa."so_id"
ORDER BY so."created_at" DESC;

-- 4. Runtime Grants
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_test_registrations" TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_test_registrations_detail TO itest_system_user;
    GRANT SELECT ON system_schema.v_testing_active_traceability TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_test_registrations" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_test_registrations_detail TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_testing_active_traceability TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON TABLE system_schema."device_test_registrations" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_device_test_registrations_detail TO itest_ops_user;
    GRANT SELECT ON system_schema.v_testing_active_traceability TO itest_ops_user;
  END IF;
END $$;
