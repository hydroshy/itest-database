-- ==============================================================================
-- MIGRATION: 001_create_traceability_manager_tables.sql
-- Module: traceability-manager
-- Schema: traceability_manager
-- Description: Creates isolated schema traceability_manager and tables:
--              1. traceability_so (Sale Orders)
--              2. traceability_wa (Work Authorizations under SO)
--              3. traceability_device (Device Units with hardware testing data
--                 matching WSLRW-C-RS485-01_tested.csv format & final config link)
--              Includes cascade foreign keys, indices, triggers, and
--              analytical Metabase lifecycle view v_device_traceability_lifecycle.
-- ==============================================================================

-- 1. Ensure Schema exists
CREATE SCHEMA IF NOT EXISTS traceability_manager;

-- 2. Ensure Required Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 3. Dedicated Migration Versioning Table for Schema `traceability_manager`
CREATE TABLE IF NOT EXISTS traceability_manager."_migrations" (
  "id" SERIAL PRIMARY KEY,
  "migration_name" VARCHAR(255) NOT NULL UNIQUE,
  "batch" INTEGER NOT NULL DEFAULT 1,
  "applied_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "checksum" VARCHAR(64)
);

-- 4. Automatic updated_at Trigger Function
CREATE OR REPLACE FUNCTION traceability_manager.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. Sale Orders Table (Tầng Đơn Bán Hàng)
CREATE TABLE IF NOT EXISTS traceability_manager."traceability_so" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "so_number" VARCHAR(50) NOT NULL UNIQUE,
  "customer_name" VARCHAR(255),
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

-- 6. Work Authorizations Table (Tầng Lệnh Sản Xuất / Lô Sản Xuất thuộc SO)
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
COMMENT ON COLUMN traceability_manager."traceability_wa"."wa_number" IS 'Mã Lệnh Sản Xuất duy nhất (Cú pháp chuẩn WA/xxxx/xxxxx, ví dụ: WA/2026/00412)';
COMMENT ON COLUMN traceability_manager."traceability_wa"."item_code" IS 'Mã chủng loại thành phẩm (ví dụ: WSLRW-C-RS485-01)';
COMMENT ON COLUMN traceability_manager."traceability_wa"."planned_quantity" IS 'Số lượng dự kiến sản xuất của lệnh';
COMMENT ON COLUMN traceability_manager."traceability_wa"."notes" IS 'Ghi chú kỹ thuật của lệnh sản xuất';

-- Trigger for updated_at on traceability_wa
DROP TRIGGER IF EXISTS trg_traceability_wa_updated_at ON traceability_manager."traceability_wa";
CREATE TRIGGER trg_traceability_wa_updated_at
BEFORE UPDATE ON traceability_manager."traceability_wa"
FOR EACH ROW
EXECUTE FUNCTION traceability_manager.set_current_timestamp_updated_at();

-- 7. Device Units & Test Results Table (Tầng Thiết Bị & Kết Quả Đo Kiểm)
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
COMMENT ON COLUMN traceability_manager."traceability_device"."test_raw_data" IS 'Dữ liệu thô JSONB lưu toàn bộ metrics bổ sung từ file CSV (start_time, duration_time, label_check_code, auto_check, calib, v.v.)';
COMMENT ON COLUMN traceability_manager."traceability_device"."final_config_session_id" IS 'Tham chiếu tới finalconfig_manager.finalconfig_execution_session(id)';
COMMENT ON COLUMN traceability_manager."traceability_device"."config_status" IS 'Trạng thái nạp cấu hình: PENDING, CONFIGURED_PASS, CONFIGURED_FAIL';
COMMENT ON COLUMN traceability_manager."traceability_device"."status" IS 'Vòng đời thiết bị: TESTED, TESTED_PASS, TESTED_FAIL, CONFIGURED, SHIPPED';

-- Trigger for updated_at on traceability_device
DROP TRIGGER IF EXISTS trg_traceability_device_updated_at ON traceability_manager."traceability_device";
CREATE TRIGGER trg_traceability_device_updated_at
BEFORE UPDATE ON traceability_manager."traceability_device"
FOR EACH ROW
EXECUTE FUNCTION traceability_manager.set_current_timestamp_updated_at();

-- Safe conditional foreign key to finalconfig_manager.finalconfig_execution_session
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'finalconfig_manager' 
      AND table_name = 'finalconfig_execution_session'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints
      WHERE constraint_schema = 'traceability_manager'
        AND constraint_name = 'fk_traceability_device_final_config_session'
    ) THEN
      ALTER TABLE traceability_manager."traceability_device"
      ADD CONSTRAINT fk_traceability_device_final_config_session
      FOREIGN KEY ("final_config_session_id")
      REFERENCES finalconfig_manager."finalconfig_execution_session"("id")
      ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

-- 8. High-Performance Indices
CREATE INDEX IF NOT EXISTS idx_traceability_so_number
  ON traceability_manager."traceability_so" ("so_number");

CREATE INDEX IF NOT EXISTS idx_traceability_wa_so_id
  ON traceability_manager."traceability_wa" ("so_id");

CREATE INDEX IF NOT EXISTS idx_traceability_wa_number
  ON traceability_manager."traceability_wa" ("wa_number");

CREATE INDEX IF NOT EXISTS idx_traceability_wa_item_code
  ON traceability_manager."traceability_wa" ("item_code");

CREATE INDEX IF NOT EXISTS idx_traceability_device_so_id
  ON traceability_manager."traceability_device" ("so_id");

CREATE INDEX IF NOT EXISTS idx_traceability_device_wa_id
  ON traceability_manager."traceability_device" ("wa_id");

CREATE INDEX IF NOT EXISTS idx_traceability_device_serial
  ON traceability_manager."traceability_device" ("serial_number");

CREATE INDEX IF NOT EXISTS idx_traceability_device_device_key
  ON traceability_manager."traceability_device" ("device_key");

CREATE INDEX IF NOT EXISTS idx_traceability_device_deveui
  ON traceability_manager."traceability_device" ("dev_eui");

CREATE INDEX IF NOT EXISTS idx_traceability_device_test_result
  ON traceability_manager."traceability_device" ("test_result");

CREATE INDEX IF NOT EXISTS idx_traceability_device_config_status
  ON traceability_manager."traceability_device" ("config_status");

CREATE INDEX IF NOT EXISTS idx_traceability_device_status
  ON traceability_manager."traceability_device" ("status");

CREATE INDEX IF NOT EXISTS idx_traceability_device_tested_at
  ON traceability_manager."traceability_device" ("tested_at" DESC);

-- GIN Index on JSONB test_raw_data for deep search queries
CREATE INDEX IF NOT EXISTS idx_traceability_device_raw_data_gin
  ON traceability_manager."traceability_device" USING GIN ("test_raw_data");

-- 9. Analytical BI View for Metabase: v_device_traceability_lifecycle
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
