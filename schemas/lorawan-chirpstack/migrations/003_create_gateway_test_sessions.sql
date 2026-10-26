-- ==============================================================================
-- MIGRATION: 003_create_gateway_test_sessions.sql
-- Module: lorawan-chirpstack
-- Schema: lorawan_chirpstack
-- Target: gateway_test_sessions
-- Description: Creates gateway_test_sessions table for tracking Gateway automated
--              test flows, packet count statistics, RSSI/SNR metrics, and session summaries.
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO lorawan_chirpstack, public;

CREATE TABLE IF NOT EXISTS lorawan_chirpstack."gateway_test_sessions" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "gateway_id" VARCHAR(64) NOT NULL,
  "gateway_name" VARCHAR(255),
  "session_name" VARCHAR(255),
  "status" VARCHAR(50) NOT NULL DEFAULT 'IN_PROGRESS',
  "started_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "ended_at" TIMESTAMPTZ,
  "summary" JSONB NOT NULL DEFAULT '{}'::jsonb,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE lorawan_chirpstack."gateway_test_sessions" IS 'Bảng ghi nhận các phiên kiểm thử chất lượng truyền nhận của Gateway LoRaWAN';
COMMENT ON COLUMN lorawan_chirpstack."gateway_test_sessions"."id" IS 'Khóa chính UUID phiên kiểm thử';
COMMENT ON COLUMN lorawan_chirpstack."gateway_test_sessions"."gateway_id" IS 'Gateway EUI (định danh 16 ký tự hex của Gateway trên ChirpStack)';
COMMENT ON COLUMN lorawan_chirpstack."gateway_test_sessions"."gateway_name" IS 'Tên hiển thị của Gateway';
COMMENT ON COLUMN lorawan_chirpstack."gateway_test_sessions"."session_name" IS 'Tên hoặc nhãn phân loại phiên kiểm thử';
COMMENT ON COLUMN lorawan_chirpstack."gateway_test_sessions"."status" IS 'Trạng thái phiên: IN_PROGRESS, COMPLETED, FAILED, CANCELLED';
COMMENT ON COLUMN lorawan_chirpstack."gateway_test_sessions"."started_at" IS 'Thời điểm bắt đầu phiên test';
COMMENT ON COLUMN lorawan_chirpstack."gateway_test_sessions"."ended_at" IS 'Thời điểm kết thúc phiên test';
COMMENT ON COLUMN lorawan_chirpstack."gateway_test_sessions"."summary" IS 'Tổng hợp kết quả kiểm thử dạng JSONB (packet_count, pass_rate, avg_rssi, avg_snr...)';

-- Trigger for auto updated_at
DROP TRIGGER IF EXISTS trg_gw_test_sessions_updated_at ON lorawan_chirpstack."gateway_test_sessions";
CREATE TRIGGER trg_gw_test_sessions_updated_at
BEFORE UPDATE ON lorawan_chirpstack."gateway_test_sessions"
FOR EACH ROW
EXECUTE FUNCTION lorawan_chirpstack.set_current_timestamp_updated_at();

-- Indexes for gateway_test_sessions
CREATE INDEX IF NOT EXISTS "idx_gw_test_sessions_gateway_id" ON lorawan_chirpstack."gateway_test_sessions"("gateway_id");
CREATE INDEX IF NOT EXISTS "idx_gw_test_sessions_status" ON lorawan_chirpstack."gateway_test_sessions"("status");
CREATE INDEX IF NOT EXISTS "idx_gw_test_sessions_started_at" ON lorawan_chirpstack."gateway_test_sessions"("started_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_gw_test_sessions_summary_gin" ON lorawan_chirpstack."gateway_test_sessions" USING GIN ("summary");

-- Runtime privileges
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE lorawan_chirpstack."gateway_test_sessions" TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE lorawan_chirpstack."gateway_test_sessions" TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON TABLE lorawan_chirpstack."gateway_test_sessions" TO itest_ops_user;
  END IF;
END $$;
