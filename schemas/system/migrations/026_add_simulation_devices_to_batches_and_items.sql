-- ==============================================================================
-- MIGRATION: 026_add_simulation_devices_to_batches_and_items.sql
-- Description: Add simulation_devices tracking for multi-simulation device support
--              in Test Batches and Items.
-- Schema: system_schema
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Extend simulation_profiles
ALTER TABLE system_schema."simulation_profiles"
  ADD COLUMN IF NOT EXISTS "simulation_devices" JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS "idx_simu_profiles_sim_devices_gin"
  ON system_schema."simulation_profiles" USING GIN ("simulation_devices");

COMMENT ON COLUMN system_schema."simulation_profiles"."simulation_devices" IS 'Danh sách các thiết bị simulation được chọn cho Flow này';

-- 2. Extend device_test_batches
ALTER TABLE system_schema."device_test_batches"
  ADD COLUMN IF NOT EXISTS "simulation_devices" JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE INDEX IF NOT EXISTS "idx_dtest_batches_sim_devices_gin"
  ON system_schema."device_test_batches" USING GIN ("simulation_devices");

COMMENT ON COLUMN system_schema."device_test_batches"."simulation_devices" IS 'Danh sách các thiết bị simulation áp dụng cho Test Batch';

-- 3. Extend device_test_batch_items
ALTER TABLE system_schema."device_test_batch_items"
  ADD COLUMN IF NOT EXISTS "simulation_devices_data" JSONB NOT NULL DEFAULT '[]'::jsonb;

COMMENT ON COLUMN system_schema."device_test_batch_items"."simulation_devices_data" IS 'Dữ liệu thiết bị simulation gán chi tiết cho từng DUT';

-- 4. Grant privileges
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA system_schema TO itest_system_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA system_schema TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON ALL TABLES IN SCHEMA system_schema TO itest_ops_user;
  END IF;
END $$;
