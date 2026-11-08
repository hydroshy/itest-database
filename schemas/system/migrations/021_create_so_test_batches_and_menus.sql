-- ==============================================================================
-- MIGRATION: 021_create_so_test_batches_and_menus.sql
-- Module: testing / so-test-batch
-- Schema: system_schema, traceability_manager
-- Target: so_test_batches, views, menu_items, permissions
-- Description:
--   1. Create system_schema.so_test_batches table linking Sales Orders (SO) from
--      traceability_manager.traceability_so to Device Test Batches in
--      system_schema.device_test_batches.
--   2. Support 1 SO having multiple Test Batches across different ITEM_CODEs.
--   3. Automatically synchronize so_number, batch_code, and item_code via trigger.
--   4. Register menu item 'SO Test Batch' as sub-menu/tab inside plugin 'testing' (LoRaWAN Testing):
--      id: 'testing:so-test-batch', route: '/plugins/testing?tab=so-test-batch', tab: 'so-test-batch'.
--      Also provide aliases for backwards compatibility.
--   5. Create views:
--      - system_schema.v_so_test_batches_detail: Detailed joined view with batch item counts.
--      - system_schema.v_so_with_test_batches: SO list with aggregated JSON array of linked test batches & item_codes.
--      - system_schema.v_available_test_batches: Real-world created/ready test batches available for linking.
--      - traceability_manager.so_test_batches: Cross-schema compat view.
--      - traceability_manager.v_so_with_test_batches: Cross-schema compat view.
--   6. Register and assign permissions to ADMIN, OPERATOR, TESTER, QA_ENGINEER, TECHNICIAN roles.
--   7. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- ==============================================================================

SET search_path TO system_schema, traceability_manager, public;

-- 1. Create system_schema.so_test_batches table
CREATE TABLE IF NOT EXISTS system_schema."so_test_batches" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "so_id" UUID NOT NULL REFERENCES traceability_manager."traceability_so"("id") ON DELETE CASCADE,
  "batch_id" UUID NOT NULL REFERENCES system_schema."device_test_batches"("id") ON DELETE CASCADE,
  "so_number" VARCHAR(50) NOT NULL,
  "batch_code" VARCHAR(100) NOT NULL,
  "item_code" VARCHAR(100),
  "notes" TEXT,
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'operator',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT uq_so_test_batches_so_batch UNIQUE ("so_id", "batch_id"),
  CONSTRAINT uq_so_test_batches_number_code UNIQUE ("so_number", "batch_code")
);

-- Idempotently ensure item_code column exists if table was pre-created
ALTER TABLE system_schema."so_test_batches" ADD COLUMN IF NOT EXISTS "item_code" VARCHAR(100);

COMMENT ON TABLE system_schema."so_test_batches" IS 'Bảng liên kết quan hệ 1-N giữa Đơn Bán Hàng (SO) và các Đợt kiểm thử lô (Device Test Batches) theo từng ITEM_CODE';
COMMENT ON COLUMN system_schema."so_test_batches"."so_id" IS 'Tham chiếu khóa ngoại đến traceability_manager.traceability_so(id) với CASCADE DELETE';
COMMENT ON COLUMN system_schema."so_test_batches"."batch_id" IS 'Tham chiếu khóa ngoại đến system_schema.device_test_batches(id) với CASCADE DELETE';
COMMENT ON COLUMN system_schema."so_test_batches"."so_number" IS 'Mã SO đồng bộ để truy vấn nhanh không cần JOIN';
COMMENT ON COLUMN system_schema."so_test_batches"."batch_code" IS 'Mã Test Batch đồng bộ để truy vấn nhanh không cần JOIN';
COMMENT ON COLUMN system_schema."so_test_batches"."item_code" IS 'Mã ITEM_CODE của Test Batch để hỗ trợ 1 SO có nhiều Test Batch cho các ITEM_CODE khác nhau';

-- 2. Indexes for high-performance lookup
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_so_id" ON system_schema."so_test_batches" ("so_id");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_batch_id" ON system_schema."so_test_batches" ("batch_id");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_so_number" ON system_schema."so_test_batches" ("so_number");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_batch_code" ON system_schema."so_test_batches" ("batch_code");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_item_code" ON system_schema."so_test_batches" ("item_code");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_so_item" ON system_schema."so_test_batches" ("so_id", "item_code");
CREATE INDEX IF NOT EXISTS "idx_so_test_batches_created_at" ON system_schema."so_test_batches" ("created_at" DESC);

-- 3. Trigger for automatic code synchronization
CREATE OR REPLACE FUNCTION system_schema.sync_so_test_batches_codes()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.so_number IS NULL OR NEW.so_number = '' THEN
    SELECT so_number INTO NEW.so_number FROM traceability_manager.traceability_so WHERE id = NEW.so_id;
  END IF;
  IF NEW.batch_code IS NULL OR NEW.batch_code = '' THEN
    SELECT batch_code, item_code INTO NEW.batch_code, NEW.item_code FROM system_schema.device_test_batches WHERE id = NEW.batch_id;
  END IF;
  IF NEW.item_code IS NULL OR NEW.item_code = '' THEN
    SELECT item_code INTO NEW.item_code FROM system_schema.device_test_batches WHERE id = NEW.batch_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_so_test_batches_codes ON system_schema."so_test_batches";
CREATE TRIGGER trg_sync_so_test_batches_codes
BEFORE INSERT OR UPDATE ON system_schema."so_test_batches"
FOR EACH ROW
EXECUTE FUNCTION system_schema.sync_so_test_batches_codes();

-- 4. Trigger for updated_at
DROP TRIGGER IF EXISTS trg_so_test_batches_updated_at ON system_schema."so_test_batches";
CREATE TRIGGER trg_so_test_batches_updated_at
BEFORE UPDATE ON system_schema."so_test_batches"
FOR EACH ROW
EXECUTE FUNCTION system_schema.set_current_timestamp_updated_at();

-- 5. Create Views
-- 5.1 Detailed Link View
DROP VIEW IF EXISTS system_schema.v_so_test_batches_detail CASCADE;
CREATE OR REPLACE VIEW system_schema.v_so_test_batches_detail AS
SELECT
  sotb."id" AS "link_id",
  sotb."so_id",
  so."so_number",
  so."customer_name",
  so."customer_email",
  so."partner_email",
  so."created_at" AS "so_created_at",
  sotb."batch_id",
  b."batch_code",
  b."batch_name",
  COALESCE(sotb."item_code", b."item_code") AS "item_code",
  b."long_fw",
  b."fw_version",
  b."simu_id",
  b."flow_duration_seconds",
  b."max_devices",
  b."status" AS "batch_status",
  b."verdict" AS "batch_verdict",
  b."duration_seconds",
  b."started_at" AS "batch_started_at",
  b."finished_at" AS "batch_finished_at",
  COALESCE(
    (SELECT COUNT(*)::int FROM system_schema."device_test_batch_items" bi WHERE bi."batch_id" = b."id"),
    0
  ) AS "device_count",
  sotb."created_at" AS "linked_at",
  sotb."created_by" AS "linked_by",
  sotb."notes",
  sotb."metadata"
FROM system_schema."so_test_batches" sotb
JOIN traceability_manager."traceability_so" so ON sotb."so_id" = so."id"
JOIN system_schema."device_test_batches" b ON sotb."batch_id" = b."id";

COMMENT ON VIEW system_schema.v_so_test_batches_detail IS 'View chi tiết liên kết giữa Đơn Bán Hàng (SO) và Device Test Batch kèm thông số kỹ thuật';

-- 5.2 Aggregated SO View for Tabulator (supports 1 SO having multiple Test Batches for different ITEM_CODEs)
DROP VIEW IF EXISTS system_schema.v_so_with_test_batches CASCADE;
CREATE OR REPLACE VIEW system_schema.v_so_with_test_batches AS
SELECT
  so."id" AS "so_id",
  so."so_number",
  so."customer_name",
  so."customer_email",
  so."partner_email",
  so."notes",
  so."created_at",
  so."updated_at",
  COALESCE(
    JSONB_AGG(
      JSONB_BUILD_OBJECT(
        'linkId', sotb."id",
        'batchId', b."id",
        'batchCode', b."batch_code",
        'batchName', b."batch_name",
        'itemCode', COALESCE(sotb."item_code", b."item_code"),
        'longFw', b."long_fw",
        'fwVersion', b."fw_version",
        'status', b."status",
        'verdict', b."verdict",
        'deviceCount', COALESCE((SELECT COUNT(*)::int FROM system_schema."device_test_batch_items" bi WHERE bi."batch_id" = b."id"), 0),
        'linkedAt', sotb."created_at",
        'linkedBy', sotb."created_by"
      ) ORDER BY sotb."created_at" DESC
    ) FILTER (WHERE b."id" IS NOT NULL),
    '[]'::jsonb
  ) AS "test_batches",
  COALESCE(
    (
      SELECT JSONB_AGG(DISTINCT sub_b."item_code")
      FROM system_schema."so_test_batches" sub_sotb
      JOIN system_schema."device_test_batches" sub_b ON sub_sotb."batch_id" = sub_b."id"
      WHERE sub_sotb."so_id" = so."id" AND sub_b."item_code" IS NOT NULL
    ),
    '[]'::jsonb
  ) AS "item_codes",
  COUNT(sotb."id")::int AS "test_batch_count"
FROM traceability_manager."traceability_so" so
LEFT JOIN system_schema."so_test_batches" sotb ON so."id" = sotb."so_id"
LEFT JOIN system_schema."device_test_batches" b ON sotb."batch_id" = b."id"
GROUP BY so."id", so."so_number", so."customer_name", so."customer_email", so."partner_email", so."notes", so."created_at", so."updated_at";

COMMENT ON VIEW system_schema.v_so_with_test_batches IS 'View danh sách SO kèm mảng JSON test_batches và danh sách item_codes hỗ trợ hiển thị trên bảng Tabulator của tab SO Test Batch trong plugin LoRaWAN Testing';

-- 5.3 Available Test Batches for Modal Linking
DROP VIEW IF EXISTS system_schema.v_available_test_batches CASCADE;
CREATE OR REPLACE VIEW system_schema.v_available_test_batches AS
SELECT
  b."id",
  b."batch_code",
  b."batch_name",
  b."item_code",
  b."long_fw",
  b."fw_version",
  b."simu_id",
  b."flow_duration_seconds",
  b."max_devices",
  b."status",
  b."verdict",
  b."duration_seconds",
  b."started_at",
  b."finished_at",
  b."created_by",
  b."created_at",
  COALESCE(
    (SELECT COUNT(*)::int FROM system_schema."device_test_batch_items" bi WHERE bi."batch_id" = b."id"),
    0
  ) AS "device_count"
FROM system_schema."device_test_batches" b;

COMMENT ON VIEW system_schema.v_available_test_batches IS 'Danh sách các Test Batch thực tế sẵn có trên hệ thống để gán vào SO';

-- 5.4 Cross-schema compatibility views under traceability_manager
CREATE OR REPLACE VIEW traceability_manager."so_test_batches" AS
SELECT * FROM system_schema."so_test_batches";

CREATE OR REPLACE VIEW traceability_manager."v_so_with_test_batches" AS
SELECT * FROM system_schema.v_so_with_test_batches;

-- 6. Register Menu Item: Under LoRaWAN Testing plugin ('testing') as requested
INSERT INTO system_schema."menu_items" (
  "id", "title", "description", "route", "icon", "category", "pluginId", "tab", "order", "isActive"
) VALUES
(
  'testing:so-test-batch',
  'SO Test Batch',
  'Quản lý liên kết Sales Order (SO) và Device Test Batch theo từng ITEM_CODE',
  '/plugins/testing?tab=so-test-batch',
  'Layers',
  'plugin',
  'testing',
  'so-test-batch',
  16,
  true
),
(
  'so-test-batch:so-test-batch',
  'SO Test Batch',
  'Quản lý liên kết Sales Order (SO) và Device Test Batch',
  '/plugins/testing?tab=so-test-batch',
  'Link',
  'plugin',
  'testing',
  'so-test-batch',
  17,
  true
),
(
  'so-test-batch:main',
  'SO Test Batch',
  'Quản lý liên kết Sales Order (SO) và Device Test Batch',
  '/plugins/testing?tab=so-test-batch',
  'Link',
  'plugin',
  'testing',
  'main',
  17,
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

-- 7. Register Permissions
INSERT INTO system_schema."permission" ("name", "description", "module", "action")
VALUES
  ('menu:testing-so-test-batch:view', 'Access SO Test Batch tab in LoRaWAN Testing', 'menu', 'read'),
  ('menu:so-test-batch:view', 'Access SO Test Batch menu', 'menu', 'read'),
  ('testing:so-test-batch:manage', 'Manage SO Test Batch associations', 'testing', 'manage'),
  ('so-test-batch:link:read', 'View SO and Test Batch associations', 'so-test-batch', 'read'),
  ('so-test-batch:link:create', 'Link a Test Batch to a Sales Order', 'so-test-batch', 'create'),
  ('so-test-batch:link:delete', 'Unlink a Test Batch from a Sales Order', 'so-test-batch', 'delete')
ON CONFLICT ("name") DO UPDATE SET
  "description" = EXCLUDED."description",
  "module" = EXCLUDED."module",
  "action" = EXCLUDED."action";

-- 8. Assign Role Permissions
-- ADMIN: Full permissions
INSERT INTO system_schema."role_menu_permissions" ("roleId", "menuItemId")
SELECT r."id", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('ADMIN', 'admin')
  AND m."id" IN ('testing:so-test-batch', 'so-test-batch:so-test-batch', 'so-test-batch:main')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- OPERATOR, TESTER, QA_ENGINEER, TECHNICIAN
INSERT INTO system_schema."role_menu_permissions" ("roleId", "menuItemId")
SELECT r."id", m."id"
FROM system_schema."roles" r
CROSS JOIN system_schema."menu_items" m
WHERE r."code" IN ('OPERATOR', 'operator', 'TESTER', 'tester', 'QA_ENGINEER', 'qa_engineer', 'TECHNICIAN', 'technician')
  AND m."id" IN ('testing:so-test-batch', 'so-test-batch:so-test-batch', 'so-test-batch:main')
ON CONFLICT ("roleId", "menuItemId") DO NOTHING;

-- 9. Runtime Privilege Grants
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."so_test_batches" TO itest_system_user;
    GRANT SELECT ON system_schema.v_so_test_batches_detail TO itest_system_user;
    GRANT SELECT ON system_schema.v_so_with_test_batches TO itest_system_user;
    GRANT SELECT ON system_schema.v_available_test_batches TO itest_system_user;
    GRANT SELECT ON traceability_manager."so_test_batches" TO itest_system_user;
    GRANT SELECT ON traceability_manager."v_so_with_test_batches" TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."so_test_batches" TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_so_test_batches_detail TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_so_with_test_batches TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_available_test_batches TO itest_plugins_user;
    GRANT SELECT ON traceability_manager."so_test_batches" TO itest_plugins_user;
    GRANT SELECT ON traceability_manager."v_so_with_test_batches" TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON TABLE system_schema."so_test_batches" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_so_test_batches_detail TO itest_ops_user;
    GRANT SELECT ON system_schema.v_so_with_test_batches TO itest_ops_user;
    GRANT SELECT ON system_schema.v_available_test_batches TO itest_ops_user;
    GRANT SELECT ON traceability_manager."so_test_batches" TO itest_ops_user;
    GRANT SELECT ON traceability_manager."v_so_with_test_batches" TO itest_ops_user;
  END IF;
END $$;
