-- ==============================================================================
-- MIGRATION: 018_enhance_autocheck_profiles_for_func_library.sql
-- Module: testing / system
-- Schema: system_schema
-- Target: device_autocheck_profiles, v_device_autocheck_profiles
-- Description:
--   1. Ensure system_schema.device_autocheck_profiles exists idempotently.
--   2. Add GIN index on criteria column in device_autocheck_profiles to support
--      fast JSONB path querying for FUNC_AUTOCHECK rules:
--      (CHECKVALUE, CHECKAVG, CHECKCOUNT, FUNC_AVG, FUNC_OFFSET_AVGZERO, CHECKVALUE_PERIOD, CHECKAVG_PERIOD).
--   3. Create view v_device_autocheck_profiles exposing rule count, function names array,
--      target parameters, and reference device requirements.
--   4. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Ensure table device_autocheck_profiles exists idempotently
CREATE TABLE IF NOT EXISTS system_schema."device_autocheck_profiles" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "autocheck_id" VARCHAR(40) NOT NULL UNIQUE DEFAULT ('AC-' || upper(replace(gen_random_uuid()::text, '-', ''))),
  "name" VARCHAR(255) NOT NULL CHECK (btrim("name") <> ''),
  "item_code" VARCHAR(100) NOT NULL CHECK (btrim("item_code") <> ''),
  "fw_version" VARCHAR(100) NOT NULL CHECK (btrim("fw_version") <> ''),
  "reference_item_code" VARCHAR(100),
  "reference_fw_version" VARCHAR(100),
  "criteria" JSONB NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof("criteria") = 'object'),
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'tester',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CHECK (
    ("reference_item_code" IS NULL AND "reference_fw_version" IS NULL)
    OR ("reference_item_code" IS NOT NULL AND btrim("reference_item_code") <> ''
        AND "reference_fw_version" IS NOT NULL AND btrim("reference_fw_version") <> '')
  )
);

CREATE INDEX IF NOT EXISTS "idx_autocheck_profiles_product"
  ON system_schema."device_autocheck_profiles" ("item_code", "fw_version");

-- 2. Create GIN index on criteria JSONB & timestamp index
CREATE INDEX IF NOT EXISTS "idx_autocheck_profiles_criteria_gin"
  ON system_schema."device_autocheck_profiles" USING GIN ("criteria");

CREATE INDEX IF NOT EXISTS "idx_autocheck_profiles_created_at"
  ON system_schema."device_autocheck_profiles" ("created_at" DESC);

-- 3. Create view v_device_autocheck_profiles
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

-- 4. Grant runtime privileges
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
