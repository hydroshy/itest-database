-- ==============================================================================
-- MIGRATION: 008_extend_simulation_profiles_for_block_flow.sql
-- Description:
--   1. Add sensor_connectivity, sku, and flow_blocks JSONB to simulation_profiles table.
--   2. Add indexes for (sku, long_fw, item_code) for fast lookup in Simulation Create UI.
--   3. Create or replace view v_simulation_devices for easy listing of simulation devices
--      (status in 'simulation', 'template').
-- Schema: system_schema, public
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Alter simulation_profiles table
ALTER TABLE system_schema."simulation_profiles"
  ADD COLUMN IF NOT EXISTS "sensor_connectivity" VARCHAR(100) NOT NULL DEFAULT 'LoRaWAN',
  ADD COLUMN IF NOT EXISTS "sku" VARCHAR(100),
  ADD COLUMN IF NOT EXISTS "flow_blocks" JSONB NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN system_schema."simulation_profiles"."sensor_connectivity" IS 'Loại kết nối cảm biến (LoRaWAN, Sigfox, NB-IoT, RS485...)';
COMMENT ON COLUMN system_schema."simulation_profiles"."sku" IS 'Mã SKU model sản phẩm (ví dụ WSLRW-MB485, WSSFC-...)';
COMMENT ON COLUMN system_schema."simulation_profiles"."flow_blocks" IS 'Chuỗi Function Blocks mô phỏng kiểm thử nối tiếp nhau';

-- 2. Create index on (sku, long_fw, item_code)
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_sku_long_fw" ON system_schema."simulation_profiles"("sku", "long_fw");
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_flow_blocks_gin" ON system_schema."simulation_profiles" USING GIN ("flow_blocks");

-- 3. Create view for Simulation Devices
CREATE OR REPLACE VIEW system_schema.v_simulation_devices AS
SELECT
  d."id",
  d."serial_number",
  d."network_id",
  d."device_name",
  d."device_type",
  d."plugin_id",
  d."so_number",
  d."wa_number",
  d."item_code",
  d."status",
  d."metadata",
  d."created_at",
  d."updated_at"
FROM system_schema."devices" d
WHERE d."status" IN ('simulation', 'template')
UNION ALL
SELECT
  dev."id",
  dev."serial_number",
  dev."network_id",
  dev."device_name",
  dev."device_type",
  dev."plugin_id",
  dev."so_number",
  dev."wa_number",
  dev."item_code",
  dev."status",
  dev."metadata",
  dev."created_at",
  dev."updated_at"
FROM devices."devices" dev
WHERE dev."status" IN ('simulation', 'template')
  AND NOT EXISTS (
    SELECT 1 FROM system_schema."devices" sd WHERE sd."serial_number" = dev."serial_number"
  );

-- 4. Runtime Grants
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."simulation_profiles" TO itest_system_user;
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."simulation_profiles" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema."simulation_profiles" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_ops_user;
  END IF;
END $$;
