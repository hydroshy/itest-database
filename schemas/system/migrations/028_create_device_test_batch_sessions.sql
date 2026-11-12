-- Each start of a test batch has its own durable result snapshot.
CREATE TABLE IF NOT EXISTS system_schema.device_test_batch_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID NOT NULL REFERENCES system_schema.device_test_batches(id) ON DELETE CASCADE,
  status VARCHAR(50) NOT NULL DEFAULT 'RUNNING',
  verdict VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  started_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  finished_at TIMESTAMPTZ,
  result JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_dtest_batch_sessions_batch_started
  ON system_schema.device_test_batch_sessions (batch_id, started_at DESC);

ALTER TABLE system_schema.device_test_batches
  ADD COLUMN IF NOT EXISTS current_session_id UUID;
