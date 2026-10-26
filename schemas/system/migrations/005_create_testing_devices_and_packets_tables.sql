-- ==============================================================================
-- MIGRATION: 005_create_testing_devices_and_packets_tables.sql
-- Description: Create devices and device_packets tables in system_schema for
--              the 'testing' plugin and device management ecosystem.
--              Includes links to traceability (SO, WA, Item Code),
--              dual-payload packet storage (raw_payload + dynamic decoded_payload JSONB),
--              GIN indexes for fast JSON querying, and role permissions.
-- Schema: system_schema
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Create or ensure updated_at trigger helper in system_schema
CREATE OR REPLACE FUNCTION system_schema.set_current_timestamp_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create devices Table
CREATE TABLE IF NOT EXISTS system_schema."devices" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "serial_number" VARCHAR(100) NOT NULL UNIQUE,
  "network_id" VARCHAR(100),
  "device_name" VARCHAR(255) NOT NULL,
  "device_type" VARCHAR(100) NOT NULL DEFAULT 'end_device',
  "plugin_id" VARCHAR(128) NOT NULL DEFAULT 'testing',
  "so_id" UUID,
  "so_number" VARCHAR(100),
  "wa_id" UUID,
  "wa_number" VARCHAR(100),
  "item_code" VARCHAR(100),
  "status" VARCHAR(50) NOT NULL DEFAULT 'active',
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system_schema."devices" IS 'Bảng đăng ký và quản lý thiết bị dùng chung cho plugin testing và các plugin đo kiểm';
COMMENT ON COLUMN system_schema."devices"."id" IS 'Khóa chính UUID thiết bị';
COMMENT ON COLUMN system_schema."devices"."serial_number" IS 'Số sê-ri định danh phần cứng duy nhất (Serial Number)';
COMMENT ON COLUMN system_schema."devices"."network_id" IS 'Mã định danh mạng (DevEUI LoRaWAN, Gateway EUI, MAC, IP address)';
COMMENT ON COLUMN system_schema."devices"."device_name" IS 'Tên hiển thị hoặc mô hình của thiết bị';
COMMENT ON COLUMN system_schema."devices"."device_type" IS 'Loại thiết bị: end_device, gateway, sensor, meter, actuator';
COMMENT ON COLUMN system_schema."devices"."plugin_id" IS 'Mã định danh plugin phụ trách (mặc định: testing)';
COMMENT ON COLUMN system_schema."devices"."so_id" IS 'Liên kết khóa ngoại (nếu có) tới traceability_so(id)';
COMMENT ON COLUMN system_schema."devices"."so_number" IS 'Mã đơn bán hàng SO để đối soát nhanh';
COMMENT ON COLUMN system_schema."devices"."wa_id" IS 'Liên kết khóa ngoại (nếu có) tới traceability_wa(id)';
COMMENT ON COLUMN system_schema."devices"."wa_number" IS 'Mã lệnh sản xuất WA để truy vết dây chuyền';
COMMENT ON COLUMN system_schema."devices"."item_code" IS 'Mã chủng loại sản phẩm (SKU / Item Code)';
COMMENT ON COLUMN system_schema."devices"."status" IS 'Trạng thái hoạt động: active, testing, pass, fail, inactive';
COMMENT ON COLUMN system_schema."devices"."metadata" IS 'Dữ liệu cấu hình hoặc thuộc tính mở rộng dạng JSONB';

-- Trigger for auto updated_at on devices
DROP TRIGGER IF EXISTS trg_devices_updated_at ON system_schema."devices";
CREATE TRIGGER trg_devices_updated_at
BEFORE UPDATE ON system_schema."devices"
FOR EACH ROW
EXECUTE FUNCTION system_schema.set_current_timestamp_updated_at();

-- Safe Foreign Key references to traceability_manager if tables exist
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'traceability_manager' AND table_name = 'traceability_so'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_schema = 'system_schema' AND constraint_name = 'fk_devices_traceability_so'
    ) THEN
      ALTER TABLE system_schema."devices" 
      ADD CONSTRAINT fk_devices_traceability_so 
      FOREIGN KEY ("so_id") REFERENCES traceability_manager."traceability_so"("id") ON DELETE SET NULL;
    END IF;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'traceability_manager' AND table_name = 'traceability_wa'
  ) THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_schema = 'system_schema' AND constraint_name = 'fk_devices_traceability_wa'
    ) THEN
      ALTER TABLE system_schema."devices" 
      ADD CONSTRAINT fk_devices_traceability_wa 
      FOREIGN KEY ("wa_id") REFERENCES traceability_manager."traceability_wa"("id") ON DELETE SET NULL;
    END IF;
  END IF;
END $$;

-- Indexes for devices
CREATE INDEX IF NOT EXISTS "idx_devices_serial_number" ON system_schema."devices"("serial_number");
CREATE INDEX IF NOT EXISTS "idx_devices_network_id" ON system_schema."devices"("network_id");
CREATE INDEX IF NOT EXISTS "idx_devices_plugin_id" ON system_schema."devices"("plugin_id");
CREATE INDEX IF NOT EXISTS "idx_devices_so_number" ON system_schema."devices"("so_number");
CREATE INDEX IF NOT EXISTS "idx_devices_wa_number" ON system_schema."devices"("wa_number");
CREATE INDEX IF NOT EXISTS "idx_devices_item_code" ON system_schema."devices"("item_code");
CREATE INDEX IF NOT EXISTS "idx_devices_status" ON system_schema."devices"("status");
CREATE INDEX IF NOT EXISTS "idx_devices_so_id" ON system_schema."devices"("so_id");
CREATE INDEX IF NOT EXISTS "idx_devices_wa_id" ON system_schema."devices"("wa_id");
CREATE INDEX IF NOT EXISTS "idx_devices_metadata_gin" ON system_schema."devices" USING GIN ("metadata");

-- 3. Create device_packets Table
CREATE TABLE IF NOT EXISTS system_schema."device_packets" (
  "id" BIGSERIAL PRIMARY KEY,
  "device_id" UUID NOT NULL REFERENCES system_schema."devices"("id") ON DELETE CASCADE,
  "packet_type" VARCHAR(50) NOT NULL DEFAULT 'uplink',
  "f_port" INTEGER,
  "f_cnt" BIGINT,
  "raw_payload" TEXT,
  "decoded_payload" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "rf_info" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system_schema."device_packets" IS 'Bảng lưu trữ lịch sử các gói tin nhận/gửi từ thiết bị phục vụ debug, kiểm thử và phân tích';
COMMENT ON COLUMN system_schema."device_packets"."id" IS 'Khóa chính tăng tự động BIGSERIAL cho hiệu năng ghi cao';
COMMENT ON COLUMN system_schema."device_packets"."device_id" IS 'UUID thiết bị sở hữu gói tin';
COMMENT ON COLUMN system_schema."device_packets"."packet_type" IS 'Loại gói tin: uplink, downlink, join_request, ack, status';
COMMENT ON COLUMN system_schema."device_packets"."f_port" IS 'Cổng dữ liệu LoRaWAN (FPort) nếu có';
COMMENT ON COLUMN system_schema."device_packets"."f_cnt" IS 'Số đếm gói tin (Frame Counter) nếu có';
COMMENT ON COLUMN system_schema."device_packets"."raw_payload" IS 'Chuỗi dữ liệu thô (Hex hoặc Base64)';
COMMENT ON COLUMN system_schema."device_packets"."decoded_payload" IS 'Dữ liệu gói tin đã giải mã linh hoạt dưới dạng JSONB (không giới hạn số trường)';
COMMENT ON COLUMN system_schema."device_packets"."rf_info" IS 'Thông số truyền dẫn vô tuyến (RSSI, SNR, Gateway EUI, tần số, Spreading Factor)';
COMMENT ON COLUMN system_schema."device_packets"."created_at" IS 'Thời điểm ghi nhận gói tin';

-- Indexes for device_packets
CREATE INDEX IF NOT EXISTS "idx_device_packets_device_id_created_at" ON system_schema."device_packets"("device_id", "created_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_device_packets_packet_type" ON system_schema."device_packets"("packet_type");
CREATE INDEX IF NOT EXISTS "idx_device_packets_decoded_payload_gin" ON system_schema."device_packets" USING GIN ("decoded_payload");
CREATE INDEX IF NOT EXISTS "idx_device_packets_rf_info_gin" ON system_schema."device_packets" USING GIN ("rf_info");

-- 4. Unified Traceability Enriched View
CREATE OR REPLACE VIEW system_schema.v_devices_traceability AS
SELECT
  d."id" AS "device_id",
  d."serial_number",
  d."network_id",
  d."device_name",
  d."device_type",
  d."plugin_id",
  d."status",
  d."so_id",
  d."so_number",
  d."wa_id",
  d."wa_number",
  d."item_code",
  d."metadata",
  d."created_at",
  d."updated_at",
  so."customer_name",
  so."partner_email",
  wa."planned_quantity" AS "wa_planned_quantity"
FROM system_schema."devices" d
LEFT JOIN traceability_manager."traceability_so" so ON d."so_id" = so."id" OR d."so_number" = so."so_number"
LEFT JOIN traceability_manager."traceability_wa" wa ON d."wa_id" = wa."id" OR d."wa_number" = wa."wa_number";

-- 5. Runtime Grants to Roles
DO $$
BEGIN
  -- itest_system_user
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."devices" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_packets" TO itest_system_user;
    GRANT ALL PRIVILEGES ON SEQUENCE system_schema.device_packets_id_seq TO itest_system_user;
    GRANT SELECT ON system_schema.v_devices_traceability TO itest_system_user;
  END IF;

  -- itest_plugins_user
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_plugins_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."devices" TO itest_plugins_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."device_packets" TO itest_plugins_user;
    GRANT ALL PRIVILEGES ON SEQUENCE system_schema.device_packets_id_seq TO itest_plugins_user;
    GRANT SELECT ON system_schema.v_devices_traceability TO itest_plugins_user;
  END IF;

  -- itest_ops_user
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT USAGE ON SCHEMA system_schema TO itest_ops_user;
    GRANT SELECT ON TABLE system_schema."devices" TO itest_ops_user;
    GRANT SELECT ON TABLE system_schema."device_packets" TO itest_ops_user;
    GRANT SELECT ON system_schema.v_devices_traceability TO itest_ops_user;
  END IF;
END $$;
