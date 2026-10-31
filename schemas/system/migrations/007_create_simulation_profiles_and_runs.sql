-- ==============================================================================
-- MIGRATION: 007_create_simulation_profiles_and_runs.sql
-- Description:
--   1. Create simulation_profiles table:
--      - Allows Admin to create & bind template devices for testing simulation.
--      - Links simu_id with item_code and long_fw.
--      - Configures LoRaWAN parameters, preset sensors, and timed flow actions.
--   2. Create simulation_runs table:
--      - Tracks Sub-Admin test flow executions (e.g. 30-minute test flows, countdown,
--        timed downlinks such as buzzer trigger at 1 minute, auto termination at 30 minutes).
--      - Stores execution logs and actuator telemetry.
--   3. Seed initial standard profiles:
--      - SIMU-LORA-SP01 (ITEM-9901-SMART-PLUG / v1.2.0-rc3-long-fw-build9482)
--      - SIMU-LORA-WM02 (ITEM-5520-WATER-METER / v2.4.1-long-fw-build1029)
--      - SIMU-LORA-ENV03 (ITEM-8812-ENV-SENSOR / v1.0.5-long-fw-build3311)
--   4. Grant runtime privileges to itest_system_user, itest_plugins_user, itest_ops_user.
-- Schema: system_schema, public
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO system_schema, public;

-- 1. Create simulation_profiles Table
CREATE TABLE IF NOT EXISTS system_schema."simulation_profiles" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "simu_id" VARCHAR(100) NOT NULL UNIQUE,
  "profile_name" VARCHAR(255) NOT NULL,
  "item_code" VARCHAR(100) NOT NULL,
  "long_fw" VARCHAR(255) NOT NULL,
  "target_device_name" VARCHAR(255) NOT NULL,
  "activation" VARCHAR(20) NOT NULL DEFAULT 'OTAA',
  "dev_eui" VARCHAR(64),
  "app_eui" VARCHAR(64) DEFAULT '0000000000000000',
  "app_key" VARCHAR(64),
  "dev_addr" VARCHAR(64),
  "region" VARCHAR(50) NOT NULL DEFAULT 'AS923-1',
  "sf" VARCHAR(20) NOT NULL DEFAULT 'SF7',
  "bw" INTEGER NOT NULL DEFAULT 125,
  "f_port" INTEGER NOT NULL DEFAULT 10,
  "preset_id" VARCHAR(50) NOT NULL DEFAULT 'env',
  "flow_duration_minutes" INTEGER NOT NULL DEFAULT 30,
  "auto_terminate" BOOLEAN NOT NULL DEFAULT TRUE,
  "uplink_interval_sec" INTEGER NOT NULL DEFAULT 10,
  "timed_actions" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "metadata" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "created_by" VARCHAR(100) NOT NULL DEFAULT 'admin',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system_schema."simulation_profiles" IS 'Bảng hồ sơ thiết bị mẫu giả lập cho module Test Simulator, liên kết simu_id với item_code và long_fw';
COMMENT ON COLUMN system_schema."simulation_profiles"."id" IS 'Khóa chính UUID hồ sơ giả lập';
COMMENT ON COLUMN system_schema."simulation_profiles"."simu_id" IS 'Mã định danh duy nhất của kịch bản giả lập (VD: SIMU-LORA-SP01)';
COMMENT ON COLUMN system_schema."simulation_profiles"."item_code" IS 'Mã vật tư/sản phẩm (Item Code)';
COMMENT ON COLUMN system_schema."simulation_profiles"."long_fw" IS 'Phiên bản Firmware chi tiết (Long Firmware version)';
COMMENT ON COLUMN system_schema."simulation_profiles"."timed_actions" IS 'Danh sách các hành động có định giờ trong flow (VD: bật còi giả lập phút thứ 1, tắt còi phút thứ 15, kết thúc phút thứ 30)';

-- Trigger for auto updated_at
DROP TRIGGER IF EXISTS trg_simulation_profiles_updated_at ON system_schema."simulation_profiles";
CREATE TRIGGER trg_simulation_profiles_updated_at
BEFORE UPDATE ON system_schema."simulation_profiles"
FOR EACH ROW
EXECUTE FUNCTION system_schema.set_current_timestamp_updated_at();

-- Indexes for simulation_profiles
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_simu_id" ON system_schema."simulation_profiles"("simu_id");
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_item_code" ON system_schema."simulation_profiles"("item_code");
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_long_fw" ON system_schema."simulation_profiles"("long_fw");
CREATE INDEX IF NOT EXISTS "idx_simu_profiles_timed_actions_gin" ON system_schema."simulation_profiles" USING GIN ("timed_actions");

-- 2. Create simulation_runs Table
CREATE TABLE IF NOT EXISTS system_schema."simulation_runs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "simu_id" VARCHAR(100) NOT NULL REFERENCES system_schema."simulation_profiles"("simu_id") ON DELETE CASCADE,
  "device_id" UUID REFERENCES system_schema."devices"("id") ON DELETE SET NULL,
  "item_code" VARCHAR(100) NOT NULL,
  "long_fw" VARCHAR(255) NOT NULL,
  "status" VARCHAR(50) NOT NULL DEFAULT 'running', -- running, completed, stopped, failed
  "duration_seconds" INTEGER NOT NULL DEFAULT 1800,
  "elapsed_seconds" INTEGER NOT NULL DEFAULT 0,
  "speed_multiplier" INTEGER NOT NULL DEFAULT 1,
  "total_uplinks" INTEGER NOT NULL DEFAULT 0,
  "total_downlinks" INTEGER NOT NULL DEFAULT 0,
  "actuator_events" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "logs" JSONB NOT NULL DEFAULT '[]'::jsonb,
  "started_by" VARCHAR(100) NOT NULL DEFAULT 'sub_admin',
  "started_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "finished_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE system_schema."simulation_runs" IS 'Lịch sử phiên chạy flow kiểm thử giả lập của Sub-Admin';
COMMENT ON COLUMN system_schema."simulation_runs"."id" IS 'Khóa chính UUID phiên chạy';
COMMENT ON COLUMN system_schema."simulation_runs"."simu_id" IS 'Mã kịch bản giả lập tham chiếu';
COMMENT ON COLUMN system_schema."simulation_runs"."actuator_events" IS 'Nhật ký các sự kiện chấp hành (bật/tắt còi cảnh báo, đóng/mở van)';

-- Indexes for simulation_runs
CREATE INDEX IF NOT EXISTS "idx_simu_runs_simu_id" ON system_schema."simulation_runs"("simu_id");
CREATE INDEX IF NOT EXISTS "idx_simu_runs_item_code" ON system_schema."simulation_runs"("item_code");
CREATE INDEX IF NOT EXISTS "idx_simu_runs_status" ON system_schema."simulation_runs"("status");
CREATE INDEX IF NOT EXISTS "idx_simu_runs_started_at" ON system_schema."simulation_runs"("started_at" DESC);

-- 3. Seed Initial Simulation Profiles
INSERT INTO system_schema."simulation_profiles" (
  "simu_id",
  "profile_name",
  "item_code",
  "long_fw",
  "target_device_name",
  "activation",
  "dev_eui",
  "app_eui",
  "app_key",
  "region",
  "sf",
  "bw",
  "f_port",
  "preset_id",
  "flow_duration_minutes",
  "auto_terminate",
  "uplink_interval_sec",
  "timed_actions"
) VALUES
(
  'SIMU-LORA-SP01',
  'Ổ Cắm Thông Minh & Còi Báo Động (Chuẩn 30 Phút)',
  'ITEM-9901-SMART-PLUG',
  'v1.2.0-rc3-long-fw-build9482',
  'Smart Socket Multi-Sensor Node',
  'OTAA',
  '70B3D57ED005ABCD',
  '0000000000000000',
  '2B7E151628AED2A6ABF7158809CF4F3C',
  'AS923-1',
  'SF7',
  125,
  2,
  'env',
  30,
  true,
  10,
  '[
    {"id": "act-sp-1", "triggerMinute": 1, "actionType": "downlink_buzzer", "label": "Downlink bật thiết bị còi giả lập lúc 1 phút", "payloadHex": "0101", "fPort": 10},
    {"id": "act-sp-2", "triggerMinute": 5, "actionType": "downlink_command", "label": "Downlink cấu hình chu kỳ đo 15s", "payloadHex": "02000F", "fPort": 10},
    {"id": "act-sp-3", "triggerMinute": 15, "actionType": "downlink_buzzer", "label": "Downlink tắt thiết bị còi giả lập", "payloadHex": "0100", "fPort": 10},
    {"id": "act-sp-4", "triggerMinute": 30, "actionType": "change_rate", "label": "Tự động kết thúc Flow sau 30 phút", "payloadHex": "FF", "fPort": 10}
  ]'::jsonb
),
(
  'SIMU-LORA-WM02',
  'Đồng Hồ Nước Siêu Âm LoRaWAN DN15',
  'ITEM-5520-WATER-METER',
  'v2.4.1-long-fw-build1029',
  'Water Meter Ultrasonic DN15',
  'OTAA',
  '70B3D57ED0052211',
  '0000000000000000',
  '0102030405060708090A0B0C0D0E0F10',
  'VN923',
  'SF8',
  125,
  1,
  'water',
  30,
  true,
  10,
  '[
    {"id": "act-wm-1", "triggerMinute": 1, "actionType": "downlink_buzzer", "label": "Downlink đóng van ngắt nước & bật còi cảnh báo", "payloadHex": "AA000101", "fPort": 1},
    {"id": "act-wm-2", "triggerMinute": 10, "actionType": "downlink_command", "label": "Downlink mở lại van cấp nước", "payloadHex": "AA01", "fPort": 1},
    {"id": "act-wm-3", "triggerMinute": 30, "actionType": "change_rate", "label": "Tự động kết thúc sau 30 phút", "payloadHex": "FF", "fPort": 1}
  ]'::jsonb
),
(
  'SIMU-LORA-ENV03',
  'Cảm Biến Khí & Cảnh Báo Khói Cháy',
  'ITEM-8812-ENV-SENSOR',
  'v1.0.5-long-fw-build3311',
  'Gas & Smoke Industrial Node',
  'OTAA',
  '70B3D57ED0059988',
  '0000000000000000',
  'A1B2C3D4E5F60102030405060708090A',
  'AS923-1',
  'SF7',
  125,
  3,
  'env',
  30,
  true,
  10,
  '[
    {"id": "act-env-1", "triggerMinute": 1, "actionType": "downlink_buzzer", "label": "Downlink bật còi báo khói giả lập", "payloadHex": "0101", "fPort": 10},
    {"id": "act-env-2", "triggerMinute": 12, "actionType": "downlink_buzzer", "label": "Downlink tắt còi báo khói", "payloadHex": "0100", "fPort": 10},
    {"id": "act-env-3", "triggerMinute": 30, "actionType": "change_rate", "label": "Tự động kết thúc sau 30 phút", "payloadHex": "FF", "fPort": 10}
  ]'::jsonb
)
ON CONFLICT ("simu_id") DO UPDATE SET
  "profile_name" = EXCLUDED."profile_name",
  "item_code" = EXCLUDED."item_code",
  "long_fw" = EXCLUDED."long_fw",
  "target_device_name" = EXCLUDED."target_device_name",
  "activation" = EXCLUDED."activation",
  "dev_eui" = EXCLUDED."dev_eui",
  "app_key" = EXCLUDED."app_key",
  "region" = EXCLUDED."region",
  "sf" = EXCLUDED."sf",
  "bw" = EXCLUDED."bw",
  "f_port" = EXCLUDED."f_port",
  "preset_id" = EXCLUDED."preset_id",
  "flow_duration_minutes" = EXCLUDED."flow_duration_minutes",
  "timed_actions" = EXCLUDED."timed_actions",
  "updated_at" = CURRENT_TIMESTAMP;

-- 4. Runtime Grants to Roles
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."simulation_profiles" TO itest_system_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."simulation_runs" TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT ALL PRIVILEGES ON TABLE system_schema."simulation_profiles" TO itest_plugins_user;
    GRANT ALL PRIVILEGES ON TABLE system_schema."simulation_runs" TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON TABLE system_schema."simulation_profiles" TO itest_ops_user;
    GRANT SELECT ON TABLE system_schema."simulation_runs" TO itest_ops_user;
  END IF;
END $$;
