-- ==============================================================================
-- MIGRATION: 018_enhance_autocheck_profiles_for_func_library.sql
-- Module: testing / system
-- Schema: system_schema
-- Target: device_autocheck_profiles, v_device_autocheck_profiles
-- Description:
--   1. Add GIN index on criteria column in device_autocheck_profiles to support
--      fast JSONB path querying for FUNC_AUTOCHECK rules:
--      (CHECKVALUE, CHECKAVG, CHECKCOUNT, FUNC_AVG, FUNC_OFFSET_AVGZERO, CHECKVALUE_PERIOD, CHECKAVG_PERIOD).
--   2. Create view v_device_autocheck_profiles exposing rule count, function names array,
--      target parameters, and reference device requirements.
--   3. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Create GIN index on criteria JSONB
CREATE INDEX IF NOT EXISTS "idx_autocheck_profiles_criteria_gin"
  ON system_schema."device_autocheck_profiles" USING GIN ("criteria");

CREATE INDEX IF NOT EXISTS "idx_autocheck_profiles_created_at"
  ON system_schema."device_autocheck_profiles" ("created_at" DESC);

-- 2. Create view v_device_autocheck_profiles
CREATE OR REPLACE VIEW system_schema.v_device_autocheck_profiles AS
SELECT
  p."id",
  p."autocheck_id",
  p."name",
  p."item_code",
  p."fw_version",
  p."reference_item_code",
  p."reference_fw_version",
  (p."reference_item_code" IS NOT NULL AND btrim(p."reference_item_code") <> '') AS "requires_reference",
  p."criteria",
  jsonb_array_length(
    CASE
      WHEN jsonb_typeof(p."criteria"->'rules') = 'array' THEN p."criteria"->'rules'
      WHEN jsonb_typeof(p."criteria"->'customRules') = 'array' THEN p."criteria"->'customRules'
      ELSE '[]'::jsonb
    END
  ) AS "rule_count",
  p."created_by",
  p."created_at",
  p."updated_at"
FROM system_schema."device_autocheck_profiles" p;

COMMENT ON VIEW system_schema.v_device_autocheck_profiles IS 'View chi tiết các cấu hình AutoCheck theo bộ hàm tiêu chuẩn FUNC_AUTOCHECK';

-- 3. Grant runtime privileges
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."device_autocheck_profiles" TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_autocheck_profiles TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON system_schema."device_autocheck_profiles" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_autocheck_profiles TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema."device_autocheck_profiles" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_device_autocheck_profiles TO itest_ops_user;
  END IF;
END $$;
