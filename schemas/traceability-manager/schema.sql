-- ==============================================================================
-- SCHEMA DEFINITION: traceability_manager
-- Description: Isolated schema for Sale Orders (SO), Work Authorizations (WA),
--              Device Units with testing data (WSLRW-C-RS485-01_tested.csv format),
--              Final Config execution session integration, and Metabase analytics view.
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS traceability_manager;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Dedicated Migration Versioning Table
CREATE TABLE IF NOT EXISTS traceability_manager."_migrations" (
  "id" SERIAL PRIMARY KEY,
  "migration_name" VARCHAR(255) NOT NULL UNIQUE,
  "batch" INTEGER NOT NULL DEFAULT 1,
  "applied_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "checksum" VARCHAR(64)
);

-- Automatic updated_at Trigger Function
CREATE OR REPLACE FUNCTION traceability_manager.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 1. Sale Orders Table (Tầng Đơn Bán Hàng)
CREATE TABLE IF NOT EXISTS traceability_manager."traceability_so" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "so_number" VARCHAR(50) NOT NULL UNIQUE,
  "customer_name" VARCHAR(255),
  "partner_email" VARCHAR(255),
  "customer_email" VARCHAR(255),
  "notes" TEXT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE traceability_manager."traceability_so" IS 'Quản lý Đơn Bán Hàng (Sale Order - SO)';
COMMENT ON COLUMN traceability_manager."traceability_so"."id" IS 'Khóa chính UUID duy nhất';
COMMENT ON COLUMN traceability_manager."traceability_so"."so_number" IS 'Mã Đơn Bán Hàng duy nhất (ví dụ: SO/2026/01855)';
COMMENT ON COLUMN traceability_manager."traceability_so"."customer_name" IS 'Tên khách hàng hoặc đối tác mua hàng';
COMMENT ON COLUMN traceability_manager."traceability_so"."notes" IS 'Ghi chú bổ sung';

-- Trigger for updated_at on traceability_so
DROP TRIGGER IF EXISTS trg_traceability_so_updated_at ON traceability_manager."traceability_so";
CREATE TRIGGER trg_traceability_so_updated_at
BEFORE UPDATE ON traceability_manager."traceability_so"
FOR EACH ROW
EXECUTE FUNCTION traceability_manager.set_current_timestamp_updated_at();

-- 2. Work Authorizations Table (Tầng Lệnh Sản Xuất thuộc SO)
CREATE TABLE IF NOT EXISTS traceability_manager."traceability_wa" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "so_id" UUID NOT NULL REFERENCES traceability_manager."traceability_so"("id") ON DELETE CASCADE,
  "wa_number" VARCHAR(50) NOT NULL UNIQUE,
  "item_code" VARCHAR(100),
  "planned_quantity" INTEGER NOT NULL DEFAULT 0,
  "notes" TEXT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE traceability_manager."traceability_wa" IS 'Quản lý Lệnh Sản Xuất (Work Authorization - WA) thuộc Sale Order';
COMMENT ON COLUMN traceability_manager."traceability_wa"."id" IS 'Khóa chính UUID duy nhất';
COMMENT ON COLUMN traceability_manager."traceability_wa"."so_id" IS 'Tham chiếu ngoại tới traceability_so(id) với CASCADE DELETE';
COMMENT ON COLUMN traceability_manager."traceability_wa"."wa_number" IS 'Mã Lệnh Sản Xuất duy nhất (Cú pháp chuẩn WA/xxxx/xxxxx)';
COMMENT ON COLUMN traceability_manager."traceability_wa"."item_code" IS 'Mã chủng loại thành phẩm (ví dụ: WSLRW-C-RS485-01)';
COMMENT ON COLUMN traceability_manager."traceability_wa"."planned_quantity" IS 'Số lượng dự kiến sản xuất của lệnh';
COMMENT ON COLUMN traceability_manager."traceability_wa"."notes" IS 'Ghi chú kỹ thuật của lệnh sản xuất';

-- Trigger for updated_at on traceability_wa
DROP TRIGGER IF EXISTS trg_traceability_wa_updated_at ON traceability_manager."traceability_wa";
CREATE TRIGGER trg_traceability_wa_updated_at
BEFORE UPDATE ON traceability_manager."traceability_wa"
FOR EACH ROW
EXECUTE FUNCTION traceability_manager.set_current_timestamp_updated_at();

-- 3. Device Units Table (Tầng Thiết Bị & Kết Quả Đo Kiểm)
CREATE TABLE IF NOT EXISTS traceability_manager."traceability_device" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "so_id" UUID NOT NULL REFERENCES traceability_manager."traceability_so"("id") ON DELETE CASCADE,
  "wa_id" UUID REFERENCES traceability_manager."traceability_wa"("id") ON DELETE SET NULL,
  "serial_number" VARCHAR(100) NOT NULL UNIQUE,
  "device_key" VARCHAR(64),
  "dev_eui" VARCHAR(64),
  "item_code" VARCHAR(100),
  "sku" VARCHAR(100),
  "hw_version" VARCHAR(50),
  "fw_version" VARCHAR(50),
  "test_result" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  "test_id" VARCHAR(255),
  "test_station" VARCHAR(100),
  "test_person" VARCHAR(100),
  "tested_at" TIMESTAMPTZ,
  "test_raw_data" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "final_config_session_id" UUID,
  "config_status" VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  "status" VARCHAR(30) NOT NULL DEFAULT 'TESTED',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE traceability_manager."traceability_device" IS 'Quản lý từng thiết bị cá thể, liên kết SO/WA và dữ liệu kiểm thử phần cứng';
COMMENT ON COLUMN traceability_manager."traceability_device"."id" IS 'Khóa chính UUID duy nhất';
COMMENT ON COLUMN traceability_manager."traceability_device"."so_id" IS 'Tham chiếu tới traceability_so(id) (bắt buộc)';
COMMENT ON COLUMN traceability_manager."traceability_device"."wa_id" IS 'Tham chiếu tới traceability_wa(id) (có thể NULL nếu gán trực tiếp cho SO)';
COMMENT ON COLUMN traceability_manager."traceability_device"."serial_number" IS 'Số serial number phần cứng duy nhất (ví dụ: LRCR26000093)';
COMMENT ON COLUMN traceability_manager."traceability_device"."device_key" IS 'Device Key từ file CSV đo kiểm (thường là 16 ký tự hex)';
COMMENT ON COLUMN traceability_manager."traceability_device"."dev_eui" IS 'DevEUI viễn thông chuẩn hóa (16 ký tự hex)';
COMMENT ON COLUMN traceability_manager."traceability_device"."item_code" IS 'Mã vật tư/thành phẩm (ví dụ: WSLRW-C-RS485-01)';
COMMENT ON COLUMN traceability_manager."traceability_device"."sku" IS 'Mã SKU model (ví dụ: WSLRW-MB485)';
COMMENT ON COLUMN traceability_manager."traceability_device"."hw_version" IS 'Phiên bản phần cứng (ví dụ: 2H)';
COMMENT ON COLUMN traceability_manager."traceability_device"."fw_version" IS 'Phiên bản firmware (ví dụ: 5F0917)';
COMMENT ON COLUMN traceability_manager."traceability_device"."test_result" IS 'Kết quả kiểm tra phần cứng từ máy test (PASS, FAIL, PENDING). Điều kiện tiên quyết: chỉ PASS mới cho phép Final Config';
COMMENT ON COLUMN traceability_manager."traceability_device"."test_id" IS 'Mã định danh lần test từ trạm đo';
COMMENT ON COLUMN traceability_manager."traceability_device"."test_station" IS 'Tên trạm đo kiểm (ví dụ: STATION-EN-3)';
COMMENT ON COLUMN traceability_manager."traceability_device"."test_person" IS 'Kỹ thuật viên thực hiện đo kiểm (ví dụ: DO QUANG KHANH)';
COMMENT ON COLUMN traceability_manager."traceability_device"."tested_at" IS 'Thời điểm đo kiểm hoàn tất';
COMMENT ON COLUMN traceability_manager."traceability_device"."test_raw_data" IS 'Dữ liệu thô JSONB lưu toàn bộ metrics bổ sung từ file CSV';
COMMENT ON COLUMN traceability_manager."traceability_device"."final_config_session_id" IS 'Tham chiếu tới finalconfig_manager.finalconfig_execution_session(id)';
COMMENT ON COLUMN traceability_manager."traceability_device"."config_status" IS 'Trạng thái nạp cấu hình: PENDING, CONFIGURED_PASS, CONFIGURED_FAIL';
COMMENT ON COLUMN traceability_manager."traceability_device"."status" IS 'Vòng đời thiết bị: TESTED, TESTED_PASS, TESTED_FAIL, CONFIGURED, SHIPPED';

-- Trigger for updated_at on traceability_device
DROP TRIGGER IF EXISTS trg_traceability_device_updated_at ON traceability_manager."traceability_device";
CREATE TRIGGER trg_traceability_device_updated_at
BEFORE UPDATE ON traceability_manager."traceability_device"
FOR EACH ROW
EXECUTE FUNCTION traceability_manager.set_current_timestamp_updated_at();

-- High-Performance Indices
CREATE INDEX IF NOT EXISTS idx_traceability_so_number ON traceability_manager."traceability_so" ("so_number");
CREATE INDEX IF NOT EXISTS idx_traceability_wa_so_id ON traceability_manager."traceability_wa" ("so_id");
CREATE INDEX IF NOT EXISTS idx_traceability_wa_number ON traceability_manager."traceability_wa" ("wa_number");
CREATE INDEX IF NOT EXISTS idx_traceability_wa_item_code ON traceability_manager."traceability_wa" ("item_code");
CREATE INDEX IF NOT EXISTS idx_traceability_device_so_id ON traceability_manager."traceability_device" ("so_id");
CREATE INDEX IF NOT EXISTS idx_traceability_device_wa_id ON traceability_manager."traceability_device" ("wa_id");
CREATE INDEX IF NOT EXISTS idx_traceability_device_serial ON traceability_manager."traceability_device" ("serial_number");
CREATE INDEX IF NOT EXISTS idx_traceability_device_device_key ON traceability_manager."traceability_device" ("device_key");
CREATE INDEX IF NOT EXISTS idx_traceability_device_deveui ON traceability_manager."traceability_device" ("dev_eui");
CREATE INDEX IF NOT EXISTS idx_traceability_device_test_result ON traceability_manager."traceability_device" ("test_result");
CREATE INDEX IF NOT EXISTS idx_traceability_device_config_status ON traceability_manager."traceability_device" ("config_status");
CREATE INDEX IF NOT EXISTS idx_traceability_device_status ON traceability_manager."traceability_device" ("status");
CREATE INDEX IF NOT EXISTS idx_traceability_device_item_code ON traceability_manager."traceability_device" ("item_code");
CREATE INDEX IF NOT EXISTS idx_traceability_device_so_item ON traceability_manager."traceability_device" ("so_id", "item_code");
CREATE INDEX IF NOT EXISTS idx_traceability_device_tested_at ON traceability_manager."traceability_device" ("tested_at" DESC);
CREATE INDEX IF NOT EXISTS idx_traceability_device_raw_data_gin ON traceability_manager."traceability_device" USING GIN ("test_raw_data");

-- Metabase View: v_device_traceability_lifecycle
DROP VIEW IF EXISTS traceability_manager.v_device_traceability_lifecycle CASCADE;
CREATE OR REPLACE VIEW traceability_manager.v_device_traceability_lifecycle AS
SELECT
  d.id AS device_id,
  d.serial_number,
  d.device_key,
  d.dev_eui,
  COALESCE(d.item_code, wa.item_code) AS item_code,
  d.sku,
  d.hw_version,
  d.fw_version,
  d.test_result,
  d.test_id,
  d.test_station,
  d.test_person,
  d.tested_at,
  d.test_raw_data,
  (d.test_result = 'PASS') AS is_eligible_for_final_config,
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  so.partner_email,
  wa.id AS wa_id,
  wa.wa_number,
  d.final_config_session_id,
  d.config_status AS final_config_status,
  fcs.status AS final_config_session_status,
  fcs.current_step AS final_config_current_step,
  fcs.total_steps AS final_config_total_steps,
  fcs.passed_steps AS final_config_passed_steps,
  fcs.failed_steps AS final_config_failed_steps,
  fcs.started_at AS final_config_started_at,
  fcs.completed_at AS final_config_completed_at,
  fcs.error_message AS final_config_error,
  fcs.metadata AS final_config_metadata,
  d.status AS overall_status,
  d.created_at,
  d.updated_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_so so ON d.so_id = so.id
LEFT JOIN traceability_manager.traceability_wa wa ON d.wa_id = wa.id
LEFT JOIN finalconfig_manager.finalconfig_execution_session fcs ON d.final_config_session_id = fcs.id;

COMMENT ON VIEW traceability_manager.v_device_traceability_lifecycle IS 'Metabase Analytical View: Aggregates full device lifecycle spanning Sale Order (SO), Work Authorization (WA), Hardware Test CSV Results, and Final Configuration Session.';

-- Analytical View for Tree: v_so_item_summary (SO -> ITEM-CODE -> SERIALS)
DROP VIEW IF EXISTS traceability_manager.v_so_item_summary CASCADE;
CREATE OR REPLACE VIEW traceability_manager.v_so_item_summary AS
WITH wa_summary AS (
  SELECT
    wa.so_id,
    COALESCE(NULLIF(TRIM(wa.item_code), ''), 'UNKNOWN') AS item_code,
    SUM(COALESCE(wa.planned_quantity, 0)) AS planned_quantity,
    COUNT(wa.id) AS wa_count
  FROM traceability_manager."traceability_wa" wa
  GROUP BY wa.so_id, COALESCE(NULLIF(TRIM(wa.item_code), ''), 'UNKNOWN')
),
device_summary AS (
  SELECT
    d.so_id,
    COALESCE(NULLIF(TRIM(d.item_code), ''), 'UNKNOWN') AS item_code,
    COUNT(d.id) AS total_tested_serials,
    COUNT(d.id) FILTER (WHERE d.test_result = 'PASS') AS passed_serials,
    COUNT(d.id) FILTER (WHERE d.test_result = 'FAIL') AS failed_serials,
    COUNT(d.id) FILTER (WHERE d.test_result = 'PENDING') AS pending_serials,
    MIN(d.tested_at) AS first_tested_at,
    MAX(d.tested_at) AS last_tested_at
  FROM traceability_manager."traceability_device" d
  GROUP BY d.so_id, COALESCE(NULLIF(TRIM(d.item_code), ''), 'UNKNOWN')
),
all_items AS (
  SELECT so_id, item_code FROM wa_summary
  UNION
  SELECT so_id, item_code FROM device_summary
)
SELECT
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  so.partner_email,
  ai.item_code,
  COALESCE(w.planned_quantity, 0) AS planned_quantity,
  COALESCE(w.wa_count, 0) AS wa_count,
  COALESCE(d.total_tested_serials, 0) AS total_tested_serials,
  COALESCE(d.passed_serials, 0) AS passed_serials,
  COALESCE(d.failed_serials, 0) AS failed_serials,
  COALESCE(d.pending_serials, 0) AS pending_serials,
  d.first_tested_at,
  d.last_tested_at
FROM all_items ai
JOIN traceability_manager."traceability_so" so ON so.id = ai.so_id
LEFT JOIN wa_summary w ON w.so_id = ai.so_id AND w.item_code = ai.item_code
LEFT JOIN device_summary d ON d.so_id = ai.so_id AND d.item_code = ai.item_code;

COMMENT ON VIEW traceability_manager.v_so_item_summary IS 'Analytical View for Tree Structure: Aggregates item codes, planned quantities, serial counts and test results across both Work Authorizations and Devices grouped by SO, Partner Email, and Item Code.';
