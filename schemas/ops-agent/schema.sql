-- ==============================================================================
-- ITEST-OPS-AGENT - MONITORING & INFRASTRUCTURE HEALTH SCHEMA (POSTGRESQL 17)
-- ==============================================================================
-- File: schemas/ops-agent/schema.sql
-- Description: Dedicated schema for ops-agent telemetry, dynamic target registrations,
--              container/host resource metrics, alerts, and autonomous health checks.
-- Schema: ops_schema
-- ==============================================================================

SET search_path TO ops_schema, public;

-- 1. Monitored Target Registry (Dynamic multi-database, containers, hosts)
CREATE TABLE IF NOT EXISTS ops_schema."monitored_targets" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "target_name" VARCHAR(255) NOT NULL,
  "target_type" VARCHAR(100) NOT NULL, -- 'database', 'container', 'node_service', 'host'
  "endpoint" VARCHAR(255) NOT NULL,
  "check_interval_sec" INTEGER NOT NULL DEFAULT 30,
  "status" VARCHAR(50) NOT NULL DEFAULT 'unknown', -- 'healthy', 'degraded', 'critical', 'unknown'
  "configuration" JSONB DEFAULT '{}',
  "last_check_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  CONSTRAINT "UQ_target_name" UNIQUE ("target_name")
);

-- 2. Infrastructure & System Metrics Time-Series
CREATE TABLE IF NOT EXISTS ops_schema."system_metrics" (
  "id" BIGSERIAL PRIMARY KEY,
  "target_id" UUID REFERENCES ops_schema."monitored_targets"("id") ON DELETE CASCADE,
  "metric_type" VARCHAR(100) NOT NULL, -- 'cpu_usage', 'memory_usage', 'db_connections', 'disk_space', 'event_loop_lag'
  "metric_value" NUMERIC(18, 4) NOT NULL,
  "unit" VARCHAR(50),
  "metadata" JSONB DEFAULT '{}',
  "collected_at" TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- 3. Operations & Heartbeat Logs
CREATE TABLE IF NOT EXISTS ops_schema."agent_heartbeats" (
  "id" BIGSERIAL PRIMARY KEY,
  "agent_id" VARCHAR(100) NOT NULL,
  "agent_version" VARCHAR(50) NOT NULL,
  "hostname" VARCHAR(255),
  "status" VARCHAR(50) NOT NULL,
  "diagnostics" JSONB DEFAULT '{}',
  "heartbeat_at" TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- 4. Alerts & Incident Management
CREATE TABLE IF NOT EXISTS ops_schema."ops_alerts" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "target_id" UUID REFERENCES ops_schema."monitored_targets"("id") ON DELETE SET NULL,
  "severity" VARCHAR(50) NOT NULL, -- 'info', 'warning', 'error', 'critical'
  "title" VARCHAR(255) NOT NULL,
  "description" TEXT,
  "status" VARCHAR(50) NOT NULL DEFAULT 'active', -- 'active', 'acknowledged', 'resolved'
  "acknowledged_by" VARCHAR(255),
  "resolved_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- 5. Autonomous Action Logs (Auto-restarts, DB vacuuming, lock release records)
CREATE TABLE IF NOT EXISTS ops_schema."action_audit_logs" (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "action_name" VARCHAR(100) NOT NULL,
  "triggered_by" VARCHAR(100) NOT NULL DEFAULT 'ops_agent_autonomous',
  "target_service" VARCHAR(100) NOT NULL,
  "payload" JSONB DEFAULT '{}',
  "result" VARCHAR(50) NOT NULL, -- 'success', 'failure'
  "error_message" TEXT,
  "executed_at" TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);

-- Indexes for performance and retention window queries
CREATE INDEX IF NOT EXISTS "idx_metrics_target_time" ON ops_schema."system_metrics"("target_id", "collected_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_metrics_collected_at" ON ops_schema."system_metrics"("collected_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_heartbeats_agent_time" ON ops_schema."agent_heartbeats"("agent_id", "heartbeat_at" DESC);
CREATE INDEX IF NOT EXISTS "idx_alerts_status_severity" ON ops_schema."ops_alerts"("status", "severity");
CREATE INDEX IF NOT EXISTS "idx_alerts_created_at" ON ops_schema."ops_alerts"("created_at" DESC);

-- Seed Initial Target for Postgres Self-Monitoring
INSERT INTO ops_schema."monitored_targets" ("target_name", "target_type", "endpoint", "check_interval_sec", "status", "configuration")
VALUES
  ('itest_postgres_17', 'database', 'postgres://itest_ops_user:ops_secret_2026@itest-postgres:5432/itest_platform', 15, 'healthy', '{"metrics": ["connections", "table_sizes", "cache_hit_ratio"]}'::jsonb),
  ('itest_system_backend', 'node_service', 'http://itest-backend:3000/health', 30, 'unknown', '{"endpoint_type": "http"}'::jsonb),
  ('ops_agent_sidecar', 'container', 'http://127.0.0.1:3199/health', 10, 'healthy', '{"role": "diagnostics"}'::jsonb)
ON CONFLICT ("target_name") DO NOTHING;
