-- ==============================================================================
-- MIGRATION: 012_create_device_test_batches_and_menus.sql
-- Module: testing / system
-- Schema: system_schema
-- Target: device_test_batches, device_test_batch_items, menu_items, permissions
-- Description:
--   1. Create device_test_batches table for multi-device batch testing configurations
--      with ITEM-CODE, LONG_FW (FW_VERSION), Simulation Flow, and Device Autocheck.
--   2. Create device_test_batch_items table for individual DUTs in each batch,
--      supporting 1-to-1 standard reference device (thiết bị chuẩn) mapping and comparison results.
--   3. Create views: v_device_test_batches and v_device_test_batch_items_detail.
--   4. Register menu items 'Create Test Batch' (tab=create-test-batch) and 'Device Test Batch' (tab=test-batch).
--   5. Register and assign permissions to ADMIN, OPERATOR, TESTER, QA_ENGINEER, TECHNICIAN roles.
--   6. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Create system_schema.device_test_batches
CREATE TABLE IF NOT EXISTS system_schema."device_test_batches" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "batch_code" VARCHAR(100) NOT NULL UNIQUE,
  "batch_name" VARCHAR(255) NOT NULL,
  "item_code" VARCHAR(100) NOT NULL,
  "long_fw" VARCHAR(255) NOT NULL,
  "fw_version" VARCHAR(100),
  "simu_id" VARCHAR(100),
  "simulation_flow" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "flow_duration_seconds" INTEGER NOT NULL DEFAULT 600,
  "auto_check_criteria" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "max_devices" INTEGER NOT NULL DEFAULT 10,
  "status" VARCHAR(50) NOT NULL DEFAULT 'CREATED',
  -- Status enum: CREATED, READY, RUNNING, COMPLETED, STOPPED, FAILED
  "verdict" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  -- Verdict enum: PENDING, PASS, FAIL, MIXED
  "duration_seconds" INTEGER NOT NULL DEFAULT 0,
  "started_at" TIMESTAMPTZ,
  "finished_at" TIMESTAMPTZ,
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'tester',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb
);

COMMENT ON TABLE system_schema."device_test_batches" IS 'Quản lý các đợt kiểm thử thiết bị theo lô (Device Test Batch) với kịch bản Simulation Flow và Autocheck';
COMMENT ON COLUMN system_schema."device_test_batches"."item_code" IS 'Mã ITEM-CODE áp dụng cho đợt kiểm thử';
COMMENT ON COLUMN system_schema."device_test_batches"."long_fw" IS 'Phiên bản Firmware đầy đủ (FW_VERSION / LONG_FW)';
COMMENT ON COLUMN system_schema."device_test_batches"."max_devices" IS 'Số lượng thiết bị tối đa cho phép kiểm thử đồng thời trong batch';
COMMENT ON COLUMN system_schema."device_test_batches"."flow_duration_seconds" IS 'Thời gian đếm giờ thực hiện kịch bản Simulation Flow (giây)';

-- Trigger auto updated_at
DROP TRIGGER IF EXISTS trg_dtest_batches_updated_at ON system_schema."device_test_batches";
CREATE TRIGGER trg_dtest_batches_updated_at
BEFORE UPDATE ON system_schema."device_test_batches"
FOR EACH ROW
EXECUTE FUNCTION system_schema.set_current_timestamp_updated_at();

-- 2. Create system_schema.device_test_batch_items
CREATE TABLE IF NOT EXISTS system_schema."device_test_batch_items" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "batch_id" UUID NOT NULL REFERENCES system_schema."device_test_batches"("id") ON DELETE CASCADE,
  "device_test_registration_id" UUID REFERENCES system_schema."device_test_registrations"("id") ON DELETE SET NULL,
  "serial_number" VARCHAR(100) NOT NULL,
  "dev_eui" VARCHAR(64) NOT NULL,
  "item_code" VARCHAR(100) NOT NULL,
  "fw_version" VARCHAR(100),

  -- Standard Reference Device (Thiết bị chuẩn đối soát 1-1 cho từng DUT)
  "reference_device_id" UUID,
  "reference_serial_number" VARCHAR(100),
  "reference_dev_eui" VARCHAR(64),
  "reference_device_name" VARCHAR(255),

  -- Execution state & comparison
  "status" VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  -- Status enum: PENDING, RUNNING, PASS, FAIL, ERROR
  "verdict" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  "dut_values" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "reference_values" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "comparison_result" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "packets_received" INTEGER NOT NULL DEFAULT 0,
  "rules_passed" INTEGER NOT NULL DEFAULT 0,
  "rules_failed" INTEGER NOT NULL DEFAULT 0,
  "logs" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system_schema."device_test_batch_items" IS 'Các thiết bị DUT trong Test Batch, gán thiết bị chuẩn tương ứng và kết quả đối soát';
COMMENT ON COLUMN system_schema."device_test_batch_items"."reference_serial_number" IS 'Serial Number của thiết bị chuẩn được gán đối soát cho DUT này';
COMMENT ON COLUMN system_schema."device_test_batch_items"."comparison_result" IS 'Kết quả đánh giá so sánh giá trị cảm biến giữa DUT và thiết bị chuẩn';

-- Trigger auto updated_at
DROP TRIGGER IF EXISTS trg_dtest_batch_items_updated_at ON system_schema."device_test_batch_items";
CREATE TRIGGER trg_dtest_batch_items_updated_at
BEFORE UPDATE ON system_schema."device_test_batch_items"
FOR EACH ROW
EXECUTE FUNCTION system_schema.set_current_timestamp_updated_at();

-- 3. Indexes for fast lookup
CREATE INDEX IF NOT EXISTS "idx_dtest_batches_item_fw"
  ON system_schema."device_test_batches" ("item_code", "long_fw");

CREATE INDEX IF NOT EXISTS "idx_dtest_batches_status"
  ON system_schema."device_test_batches" ("status");

CREATE INDEX IF NOT EXISTS "idx_dtest_batches_created_by"
  ON system_schema."device_test_batches" ("created_by");

CREATE INDEX IF NOT EXISTS "idx_dtest_batches_created_at"
  ON system_schema."device_test_batches" ("created_at" DESC);

CREATE INDEX IF NOT EXISTS "idx_dtest_batch_items_batch_id"
  ON system_schema."device_test_batch_items" ("batch_id");

CREATE INDEX IF NOT EXISTS "idx_dtest_batch_items_serial"
  ON system_schema."device_test_batch_items" ("serial_number");

CREATE INDEX IF NOT EXISTS "idx_dtest_batch_items_dev_eui"
  ON system_schema."device_test_batch_items" ("dev_eui");

CREATE INDEX IF NOT EXISTS "idx_dtest_batch_items_ref_serial"
  ON system_schema."device_test_batch_items" ("reference_serial_number");

-- 4. Views for Batches and Items
DROP VIEW IF EXISTS system_schema.v_device_test_batches CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_test_batches AS
SELECT
  b."id",
  b."batch_code",
  b."batch_name",
  b."item_code",
  b."long_fw",
  b."fw_version",
  b."simu_id",
  b."simulation_flow",
  b."flow_duration_seconds",
  b."auto_check_criteria",
  b."max_devices",
  b."status",
  b."verdict",
  b."duration_seconds",
  b."started_at",
  b."finished_at",
  b."created_by",
  b."created_at",
  b."updated_at",
  COUNT(i."id")::INTEGER AS "total_devices",
  COUNT(CASE WHEN i."status" = 'PASS' THEN 1 END)::INTEGER AS "pass_devices",
  COUNT(CASE WHEN i."status" = 'FAIL' THEN 1 END)::INTEGER AS "fail_devices",
  COUNT(CASE WHEN i."status" = 'RUNNING' THEN 1 END)::INTEGER AS "running_devices"
FROM system_schema."device_test_batches" b
LEFT JOIN system_schema."device_test_batch_items" i
  ON b."id" = i."batch_id"
GROUP BY b."id";

DROP VIEW IF EXISTS system_schema.v_device_test_batch_items_detail CASCADE;
CREATE OR REPLACE VIEW system_schema.v_device_test_batch_items_detail AS
SELECT
  i."id",
  i."batch_id",
  b."batch_code",
  b."batch_name",
  b."item_code" AS "batch_item_code",
  b."long_fw" AS "batch_long_fw",
  b."flow_duration_seconds",
  i."device_test_registration_id",
  i."serial_number",
  i."dev_eui",
  i."item_code",
  i."fw_version",
  i."reference_device_id",
  i."reference_serial_number",
  i."reference_dev_eui",
  i."reference_device_name",
  i."status",
  i."verdict",
  i."dut_values",
  i."reference_values",
  i."comparison_result",
  i."packets_received",
  i."rules_passed",
  i."rules_failed",
  i."logs",
  i."created_at",
  i."updated_at"
FROM system_schema."device_test_batch_items" i
JOIN system_schema."device_test_batches" b
  ON i."batch_id" = b."id";

-- 5. Register Menu Items: 'Create Test Batch' and 'Device Test Batch'
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES
(
  'testing:create-test-batch',
  'Create Test Batch',
  'Tạo đợt kiểm thử với ITEM-CODE, LONG_FW, Simulation Flow và Autocheck',
  '/plugins/testing?tab=create-test-batch',
  'PlusSquare',
  'plugin',
  'testing',
  'create-test-batch',
  14,
  true
),
(
  'testing:test-batch',
  'Device Test Batch',
  'Thực thi kiểm thử batch đa thiết bị, gán thiết bị chuẩn, đếm giờ theo Simulation Flow',
  '/plugins/testing?tab=test-batch',
  'Layers',
  'plugin',
  'testing',
  'test-batch',
  15,
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

-- 6. Register Permissions
INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  ('menu:testing-create-test-batch:view', 'Access Create Test Batch tab', 'menu', 'read'),
  ('menu:testing-test-batch:view', 'Access Device Test Batch tab', 'menu', 'read'),
  ('testing:batch:create', 'Create and configure device test batches', 'testing', 'create'),
  ('testing:batch:execute', 'Start, stop and monitor device test batches', 'testing', 'execute'),
  ('testing:batch:delete', 'Delete device test batches and items', 'testing', 'delete')
ON CONFLICT ("name") DO UPDATE SET
  "description" = EXCLUDED."description",
  "module" = EXCLUDED."module",
  "action" = EXCLUDED."action";

-- 7. Assign Role Permissions
-- ADMIN: Full permissions
INSERT INTO system_schema."role_menu_permissions" ("roleId", "menuItemId")
SELECT r."id", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('ADMIN', 'admin')
  AND m."id" IN ('testing:create-test-batch', 'testing:test-batch')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- OPERATOR, TESTER, QA_ENGINEER, TECHNICIAN
INSERT INTO system_schema."role_menu_permissions" ("roleId", "menuItemId")
SELECT r."id", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('OPERATOR', 'operator', 'TESTER', 'tester', 'QA_ENGINEER', 'qa_engineer', 'TECHNICIAN', 'technician')
  AND m."id" IN ('testing:create-test-batch', 'testing:test-batch')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 8. Runtime Privilege Grants
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_test_batches" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_test_batch_items" TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_test_batches TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_test_batches" TO itest_plugins_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_test_batch_items" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_test_batches TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON TABLE system_schema."device_test_batches" TO itest_ops_user;
    GRANT SELECT ON TABLE system_schema."device_test_batch_items" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_device_test_batches TO itest_ops_user;
    GRANT SELECT ON system_schema.v_device_test_batch_items_detail TO itest_ops_user;
  END IF;
END $$;
