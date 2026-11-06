-- ==============================================================================
-- MIGRATION: 014_enhance_device_packets_and_create_payload_live_view.sql
-- Module: testing / system
-- Schema: system_schema
-- Target: device_packets, v_device_payload_live, menu_items, permissions
-- Description:
--   1. Enhance system_schema.device_packets:
--      - Allow device_id to be NULL (for packets captured before device registered).
--      - Add direct RF telemetry columns: dev_eui, rssi, snr, sf, frequency.
--      - Add indexes on dev_eui, (created_at DESC), (dev_eui, created_at DESC).
--   2. Create view v_device_payload_live joining device_packets with devices and
--      device_test_registrations, exposing standardized 6 RF metrics and dynamic decoded_payload JSONB.
--   3. Register menu item 'Device Payload' under testing plugin (order 16, tab=device-payload).
--   4. Assign menu and read permissions to system roles.
--   5. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Enhance system_schema.device_packets
ALTER TABLE system_schema."device_packets"
  ALTER COLUMN "device_id" DROP NOT NULL;

ALTER TABLE system_schema."device_packets"
  ADD COLUMN IF NOT EXISTS "dev_eui" VARCHAR(64),
  ADD COLUMN IF NOT EXISTS "rssi" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "snr" DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS "sf" VARCHAR(20),
  ADD COLUMN IF NOT EXISTS "frequency" DOUBLE PRECISION;

CREATE INDEX IF NOT EXISTS "idx_device_packets_dev_eui"
  ON system_schema."device_packets" ("dev_eui");

CREATE INDEX IF NOT EXISTS "idx_device_packets_created_desc"
  ON system_schema."device_packets" ("created_at" DESC);

CREATE INDEX IF NOT EXISTS "idx_device_packets_deveui_created"
  ON system_schema."device_packets" ("dev_eui", "created_at" DESC);

-- 2. Create view v_device_payload_live
DROP VIEW IF EXISTS system_schema.v_device_payload_live CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_payload_live AS
SELECT
  p."id",
  p."device_id",
  COALESCE(p."dev_eui", d."network_id", r."dev_eui") AS "dev_eui",
  COALESCE(d."serial_number", r."serial_number") AS "serial_number",
  COALESCE(d."device_name", r."device_name", r."serial_number", p."dev_eui") AS "device_name",
  COALESCE(d."item_code", r."item_code") AS "item_code",
  COALESCE(r."long_fw", r."fw_version") AS "fw_version",
  r."hw_version",
  p."packet_type",
  p."f_port",
  COALESCE(p."f_cnt", (p."rf_info"->>'fcnt')::BIGINT, (p."rf_info"->>'f_cnt')::BIGINT, 0) AS "f_cnt",
  COALESCE(p."rssi", (p."rf_info"->>'rssi')::DOUBLE PRECISION) AS "rssi",
  COALESCE(p."snr", (p."rf_info"->>'snr')::DOUBLE PRECISION) AS "snr",
  COALESCE(p."sf", p."rf_info"->>'sf', p."rf_info"->>'spreading_factor', p."rf_info"->>'spreadingFactor', 'SF7') AS "sf",
  COALESCE(p."frequency", (p."rf_info"->>'frequency')::DOUBLE PRECISION) AS "frequency",
  p."raw_payload",
  p."decoded_payload",
  p."rf_info",
  p."created_at"
FROM system_schema."device_packets" p
LEFT JOIN system_schema."devices" d
  ON p."device_id" = d."id"
LEFT JOIN system_schema."device_test_registrations" r
  ON (p."dev_eui" = r."dev_eui" OR d."network_id" = r."dev_eui");

-- 3. Register 'Device Payload' Menu Item
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES (
  'testing:device-payload',
  'Device Payload',
  'Bảng dữ liệu nhận và giải mã payload từ ChirpStack HTTP Integration theo từng loại cảm biến',
  '/plugins/testing?tab=device-payload',
  'Activity',
  'plugin',
  'testing',
  'device-payload',
  16,
  true
)
ON CONFLICT ("id") DO UPDATE SET
  "title" = EXCLUDED."title",
  "description" = EXCLUDED."description",
  "route" = EXCLUDED."route",
  "icon" = EXCLUDED."icon",
  "category" = EXCLUDED."category",
  "pluginId" = EXCLUDED."pluginId",
  "tab" = EXCLUDED."tab",
  "order" = EXCLUDED."order",
  "isActive" = EXCLUDED."isActive",
  "updated_at" = CURRENT_TIMESTAMP;

-- 4. Register and Assign Permissions
INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  ('menu:testing-device-payload:view', 'Access Device Payload tab', 'menu', 'read'),
  ('testing:payload:read', 'View live decoded device payloads and RF metrics', 'testing', 'read')
ON CONFLICT ("name") DO UPDATE SET
  "description" = EXCLUDED."description",
  "module" = EXCLUDED."module",
  "action" = EXCLUDED."action";

DO $$
DECLARE
  v_role RECORD;
  v_perm RECORD;
BEGIN
  FOR v_role IN
    SELECT id, code FROM system_schema."roles"
    WHERE code IN ('SUPER_ADMIN', 'admin', 'SUB_ADMIN', 'sub_admin', 'OPERATOR', 'operator', 'TESTER', 'tester', 'QA_ENGINEER', 'TECHNICIAN', 'END_USER', 'user')
  LOOP
    FOR v_perm IN
      SELECT id FROM system_schema."permission"
      WHERE name IN ('menu:testing-device-payload:view', 'testing:payload:read')
    LOOP
      INSERT INTO system_schema."role_permissions" ("role_id", "permission_id", "roleCode")
      VALUES (v_role.id, v_perm.id, v_role.code)
      ON CONFLICT DO NOTHING;
    END LOOP;
  END LOOP;
END $$;

-- 5. Grant Runtime Privileges
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."device_packets" TO itest_system_user;
    GRANT USAGE, SELECT ON SEQUENCE system_schema."device_packets_id_seq" TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_payload_live TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."device_packets" TO itest_plugins_user;
    GRANT USAGE, SELECT ON SEQUENCE system_schema."device_packets_id_seq" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_payload_live TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema."device_packets" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_device_payload_live TO itest_ops_user;
  END IF;
END $$;
