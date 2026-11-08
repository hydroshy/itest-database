-- ==============================================================================
-- MIGRATION: 006_enhance_testing_devices_views_and_metrics.sql
-- Description: Create v_device_test_metrics_report and enhance v_device_traceability_lifecycle
--              to cleanly expose standard testing columns:
--              SERIAL_NUMBER, DEV_EUI, SO_NUMBER, WA_NUMBER, ITEM_CODE,
--              HW_VERSION, FW_VERSION, RESULT, TESTED BY, TIME TEST,
--              plus RF metrics (AVG_CYCLE, AVG_RSSI, AVG_SNR), tolerance checks,
--              and full packet timeline.
-- Module: traceability-manager / device-traceability
-- Schema: traceability_manager
-- Idempotency: Safe to re-run on existing PostgreSQL volumes.
-- ==============================================================================

SET search_path TO traceability_manager, public;

-- 1. Create or replace view v_device_test_metrics_report
DROP VIEW IF EXISTS traceability_manager.v_device_test_metrics_report CASCADE;
CREATE OR REPLACE VIEW traceability_manager.v_device_test_metrics_report AS
SELECT
  d.id AS device_id,
  d.serial_number,
  d.dev_eui,
  so.so_number,
  wa.wa_number,
  COALESCE(d.item_code, wa.item_code) AS item_code,
  d.hw_version,
  d.fw_version,
  d.test_result AS result,
  COALESCE(d.test_person, 'tester') AS tested_by,
  d.tested_at AS time_test,
  d.test_station,
  d.test_id,
  -- RF Metrics extracted from test_raw_data JSON
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_cycle')::numeric,
    (d.test_raw_data->>'avg_cycle')::numeric,
    (d.test_raw_data->>'avgCycle')::numeric
  ) AS avg_cycle,
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_rssi')::numeric,
    (d.test_raw_data->>'avg_rssi')::numeric,
    (d.test_raw_data->>'avgRssi')::numeric
  ) AS avg_rssi,
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_snr')::numeric,
    (d.test_raw_data->>'avg_snr')::numeric,
    (d.test_raw_data->>'avgSnr')::numeric
  ) AS avg_snr,
  COALESCE(
    (d.test_raw_data->'comparison'->>'packets_received')::int,
    (d.test_raw_data->>'packets_received')::int,
    jsonb_array_length(COALESCE(d.test_raw_data->'comparison'->'dut_packets', '[]'::jsonb))
  ) AS packets_received,
  -- Tolerance comparison against golden reference
  COALESCE(
    (d.test_raw_data->'comparison'->>'tolerance_pass')::boolean,
    (d.test_raw_data->>'tolerance_pass')::boolean
  ) AS tolerance_pass,
  (d.test_raw_data->'comparison'->>'temp_delta')::numeric AS temp_delta,
  (d.test_raw_data->'comparison'->>'hum_delta')::numeric AS hum_delta,
  -- Raw data and packet timeline payloads
  COALESCE(d.test_raw_data->'comparison'->'dut_packets', '[]'::jsonb) AS dut_packets,
  COALESCE(d.test_raw_data->'comparison'->'reference_packets', '[]'::jsonb) AS reference_packets,
  d.test_raw_data,
  d.status,
  d.created_at,
  d.updated_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_so so ON d.so_id = so.id
LEFT JOIN traceability_manager.traceability_wa wa ON d.wa_id = wa.id;

COMMENT ON VIEW traceability_manager.v_device_test_metrics_report IS 'Báo cáo chi tiết metrics kiểm thử thiết bị (AVG_CYCLE, AVG_RSSI, AVG_SNR, dung sai chuẩn, timeline gói tin) cho Device Traceability';

-- 2. Enhance v_device_traceability_lifecycle to also expose RF metrics
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
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_cycle')::numeric,
    (d.test_raw_data->>'avg_cycle')::numeric,
    (d.test_raw_data->>'avgCycle')::numeric
  ) AS avg_cycle,
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_rssi')::numeric,
    (d.test_raw_data->>'avg_rssi')::numeric,
    (d.test_raw_data->>'avgRssi')::numeric
  ) AS avg_rssi,
  COALESCE(
    (d.test_raw_data->'comparison'->>'avg_snr')::numeric,
    (d.test_raw_data->>'avg_snr')::numeric,
    (d.test_raw_data->>'avgSnr')::numeric
  ) AS avg_snr,
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

COMMENT ON VIEW traceability_manager.v_device_traceability_lifecycle IS 'Metabase Analytical View: Aggregates full device lifecycle spanning Sale Order (SO), Work Authorization (WA), Hardware Test CSV Results, RF metrics, and Final Configuration Session.';

-- 3. Grant runtime privileges
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON traceability_manager.v_device_test_metrics_report TO itest_system_user;
    GRANT SELECT ON traceability_manager.v_device_traceability_lifecycle TO itest_system_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON traceability_manager.v_device_test_metrics_report TO itest_plugins_user;
    GRANT SELECT ON traceability_manager.v_device_traceability_lifecycle TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON traceability_manager.v_device_test_metrics_report TO itest_ops_user;
    GRANT SELECT ON traceability_manager.v_device_traceability_lifecycle TO itest_ops_user;
  END IF;
END $$;
