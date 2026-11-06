-- Preserve sub-minute delays and prevent deleting flows used by any test batch.
SET search_path TO system_schema, public;

-- This view depends on the column type. Do not CASCADE into unrelated views.
DROP VIEW IF EXISTS system_schema.v_simulation_flows;
ALTER TABLE system_schema.simulation_profiles
  ALTER COLUMN flow_duration_minutes TYPE NUMERIC USING flow_duration_minutes::numeric;

CREATE OR REPLACE VIEW system_schema.v_simulation_flows AS
SELECT
  p.id,
  p.simu_id,
  COALESCE(p.name, p.profile_name, p.simu_id) AS name,
  p.description,
  p.item_code,
  p.sku,
  p.long_fw,
  COALESCE(p.sensor_connectivity, 'LoRaWAN') AS sensor_connectivity,
  p.flow_duration_minutes,
  p.flow_blocks,
  jsonb_array_length(CASE WHEN jsonb_typeof(p.flow_blocks) = 'array'
    THEN p.flow_blocks ELSE '[]'::jsonb END) AS block_count,
  p.timed_actions,
  p.created_by,
  p.created_at,
  p.updated_at
FROM system_schema.simulation_profiles p;

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_system_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.v_simulation_flows TO itest_ops_user;
  END IF;
END $$;

-- Older clients sent the profile UUID instead of its public simu_id.
-- Prefer an existing canonical match if a public ID itself looks like a UUID.
UPDATE system_schema.device_test_batches b
SET simu_id = p.simu_id
FROM system_schema.simulation_profiles p
WHERE b.simu_id = p.id::text
  AND NOT EXISTS (
    SELECT 1 FROM system_schema.simulation_profiles canonical
    WHERE canonical.simu_id = b.simu_id
  );
UPDATE system_schema.device_test_batches SET simu_id = NULL WHERE btrim(simu_id) = '';

CREATE INDEX IF NOT EXISTS idx_dtest_batches_simu_id
  ON system_schema.device_test_batches (simu_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'fk_device_test_batches_simulation_flow'
      AND conrelid = 'system_schema.device_test_batches'::regclass
  ) THEN
    -- Keep legacy orphan IDs for audit. New/changed links must reference a flow;
    -- existing valid links still block deletes, including concurrent API writes.
    ALTER TABLE system_schema.device_test_batches
      ADD CONSTRAINT fk_device_test_batches_simulation_flow
      FOREIGN KEY (simu_id) REFERENCES system_schema.simulation_profiles (simu_id)
      ON DELETE RESTRICT NOT VALID;
  END IF;
END $$;
