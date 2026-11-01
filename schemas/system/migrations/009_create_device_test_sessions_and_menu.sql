-- ==============================================================================
-- MIGRATION: 009_create_device_test_sessions_and_menu.sql
-- Description:
--   1. Register 'Create Device Testing' sub-menu under 'testing' plugin:
--      - id: 'testing:create-device-testing'
--      - route: '/plugins/testing?tab=create-device-testing'
--      - permissions: 'menu:testing-create-device:view', 'testing:device:create'
--   2. Create table system_schema.device_test_sessions:
--      - Manages device testing execution sessions (DUT / serial_number / dev_eui / simu_id).
--      - Stores flow configuration, auto-check criteria, evaluation verdicts, logs.
--      - Status: IDLE, RUNNING, EVALUATING, PASSED, FAILED, CANCELLED.
--   3. Create indexes and compatibility view v_device_test_sessions.
--   4. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- Note: NO MOCK DATA inserted.
-- Schema: system_schema, public
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Create device_test_sessions Table
CREATE TABLE IF NOT EXISTS system_schema."device_test_sessions" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "session_code" VARCHAR(100) NOT NULL UNIQUE,
  "device_id" UUID,
  "serial_number" VARCHAR(100),
  "dev_eui" VARCHAR(64),
  "device_name" VARCHAR(255),
  "item_code" VARCHAR(100),
  "sku" VARCHAR(100),
  "connectivity" VARCHAR(50) NOT NULL DEFAULT 'LoRaWAN',
  "simu_id" VARCHAR(100),
  "flow_config" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "auto_check_criteria" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "evaluation_result" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "status" VARCHAR(50) NOT NULL DEFAULT 'IDLE',
  "verdict" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  "packets_received" INTEGER NOT NULL DEFAULT 0,
  "rules_passed" INTEGER NOT NULL DEFAULT 0,
  "rules_failed" INTEGER NOT NULL DEFAULT 0,
  "duration_seconds" INTEGER NOT NULL DEFAULT 0,
  "logs" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "tested_by" VARCHAR(100) NOT NULL DEFAULT 'operator',
  "started_at" TIMESTAMPTZ,
  "finished_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system_schema."device_test_sessions" IS 'Bảng lưu trữ các phiên kiểm thử thiết bị (Create Device Testing) trong plugin testing';
COMMENT ON COLUMN system_schema."device_test_sessions"."id" IS 'Khóa chính UUID của phiên kiểm thử';
COMMENT ON COLUMN system_schema."device_test_sessions"."session_code" IS 'Mã định danh phiên kiểm thử duy nhất (VD: DTEST-20261101-001)';
COMMENT ON COLUMN system_schema."device_test_sessions"."simu_id" IS 'Mã kịch bản simulation liên kết (nếu có)';
COMMENT ON COLUMN system_schema."device_test_sessions"."flow_config" IS 'Cấu hình luồng thực thi kịch bản kiểm thử dạng JSONB';
COMMENT ON COLUMN system_schema."device_test_sessions"."auto_check_criteria" IS 'Bộ tiêu chí đánh giá tự động (RF RSSI/SNR, FPort, trường payload)';
COMMENT ON COLUMN system_schema."device_test_sessions"."evaluation_result" IS 'Chi tiết kết quả đánh giá các tiêu chí';
COMMENT ON COLUMN system_schema."device_test_sessions"."status" IS 'Trạng thái phiên: IDLE, RUNNING, EVALUATING, PASSED, FAILED, CANCELLED';
COMMENT ON COLUMN system_schema."device_test_sessions"."verdict" IS 'Đánh giá chung: PENDING, PASS, FAIL, ERROR';

-- Trigger auto updated_at
DROP TRIGGER IF EXISTS trg_device_test_sessions_updated_at ON system_schema."device_test_sessions";
CREATE TRIGGER trg_device_test_sessions_updated_at
BEFORE UPDATE ON system_schema."device_test_sessions"
FOR EACH ROW
EXECUTE FUNCTION system_schema.set_current_timestamp_updated_at();

-- Indexes for device_test_sessions
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_serial_number" ON system_schema."device_test_sessions"("serial_number");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_dev_eui" ON system_schema."device_test_sessions"("dev_eui");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_item_code" ON system_schema."device_test_sessions"("item_code");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_sku" ON system_schema."device_test_sessions"("sku");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_simu_id" ON system_schema."device_test_sessions"("simu_id");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_status" ON system_schema."device_test_sessions"("status");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_verdict" ON system_schema."device_test_sessions"("verdict");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_started_at" ON system_schema."device_test_sessions"("started_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_created_at" ON system_schema."device_test_sessions"("created_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_flow_config_gin" ON system_schema."device_test_sessions" USING GIN ("flow_config");
CREATE INDEX IF NOT EXISTS "idx_dtest_sessions_auto_check_gin" ON system_schema."device_test_sessions" USING GIN ("auto_check_criteria");

-- 2. Register 'Create Device Testing' Menu Item
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES (
  'testing:create-device-testing',
  'Create Device Testing',
  'Tạo và cấu hình phiên kiểm thử thiết bị với kịch bản Flow và tiêu chí Auto-Check',
  '/plugins/testing?tab=create-device-testing',
  'PlusCircle',
  'plugin',
  'testing',
  'create-device-testing',
  12,
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

-- 3. Register Permissions
INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  ('menu:testing-create-device:view', 'Access Create Device Testing tab', 'menu', 'read'),
  ('testing:device:create', 'Create and configure device testing sessions', 'testing', 'create'),
  ('testing:device:execute', 'Execute and monitor device testing sessions', 'testing', 'execute')
ON CONFLICT ("name") DO UPDATE SET
  "description" = EXCLUDED."description",
  "module" = EXCLUDED."module",
  "action" = EXCLUDED."action";

-- 4. Assign Role Permissions
-- ADMIN
INSERT INTO system_schema."role_menu_permissions" ("roleId", "menuItemId")
SELECT r."id", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('ADMIN', 'admin')
  AND m."id" = 'testing:create-device-testing'
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- OPERATOR
INSERT INTO system_schema."role_menu_permissions" ("roleId", "menuItemId")
SELECT r."id", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('OPERATOR', 'operator', 'TESTER', 'tester', 'QA_ENGINEER', 'qa_engineer')
  AND m."id" = 'testing:create-device-testing'
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 5. Compatibility View
CREATE OR REPLACE VIEW system_schema.v_device_test_sessions AS
SELECT
  dts."id",
  dts."session_code",
  dts."device_id",
  dts."serial_number",
  dts."dev_eui",
  dts."device_name",
  dts."item_code",
  dts."sku",
  dts."connectivity",
  dts."simu_id",
  dts."flow_config",
  dts."auto_check_criteria",
  dts."evaluation_result",
  dts."status",
  dts."verdict",
  dts."packets_received",
  dts."rules_passed",
  dts."rules_failed",
  dts."duration_seconds",
  dts."logs",
  dts."metadata",
  dts."tested_by",
  dts."started_at",
  dts."finished_at",
  dts."created_at",
  dts."updated_at"
FROM system_schema."device_test_sessions" dts;

-- 6. Runtime Privilege Grants
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_test_sessions" TO itest_system_user;
    GRANT SELECT ON system_schema.v_device_test_sessions TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_test_sessions" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_device_test_sessions TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON TABLE system_schema."device_test_sessions" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_device_test_sessions TO itest_ops_user;
  END IF;
END $$;
