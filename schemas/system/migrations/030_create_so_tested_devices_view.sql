-- ==============================================================================
-- MIGRATION: 030_create_so_tested_devices_view.sql
-- Module: final-config / traceability
-- Schema: system_schema
-- Description: Creates unified view v_so_tested_devices combining tested devices
--              from traceability_manager.traceability_device and
--              system_schema.device_test_registrations for Final Config linkage.
-- ==============================================================================

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'system_schema' AND c.relname = 'v_so_tested_devices' AND c.relkind = 'v'
  ) THEN
    DROP VIEW system_schema.v_so_tested_devices CASCADE;
  END IF;
END $$;

CREATE OR REPLACE VIEW system_schema.v_so_tested_devices AS
SELECT
  d.id AS device_id,
  d.serial_number,
  d.dev_eui,
  so.so_number,
  wa.wa_number,
  d.item_code,
  d.sku,
  d.hw_version,
  d.fw_version,
  d.test_result,
  d.test_station,
  d.test_person,
  d.tested_at,
  d.config_status,
  d.final_config_session_id,
  COALESCE(d.config_person, d.test_raw_data->'final_config_audit'->>'operator') AS config_person,
  d.configured_at,
  COALESCE(d.app_eui, d.test_raw_data->>'app_eui', d.test_raw_data->>'appeui', '0000000000000000') AS app_eui,
  COALESCE(d.app_key, d.test_raw_data->>'app_key', d.test_raw_data->'final_config_audit'->>'app_key') AS app_key,
  'traceability_device'::varchar(50) AS source_table
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_so so ON d.so_id = so.id
LEFT JOIN traceability_manager.traceability_wa wa ON d.wa_id = wa.id
UNION ALL
SELECT
  r.id AS device_id,
  COALESCE(r.serial_number, r.dev_eui) AS serial_number,
  r.dev_eui,
  r.so_number,
  r.wa_number,
  r.item_code,
  NULL::varchar(100) AS sku,
  r.hw_version,
  COALESCE(r.long_fw, r.fw_version) AS fw_version,
  CASE
    WHEN r.status IN ('SUCCESS_ATTACH_BATTERY', 'COMPLETED', 'PASS') THEN 'PASS'::varchar(20)
    WHEN r.status ILIKE '%fail%' OR r.status ILIKE '%error%' THEN 'FAIL'::varchar(20)
    ELSE 'PENDING'::varchar(20)
  END AS test_result,
  r.network_server_name AS test_station,
  r.created_by AS test_person,
  r.created_at AS tested_at,
  'PENDING'::varchar(20) AS config_status,
  NULL::uuid AS final_config_session_id,
  NULL::varchar(100) AS config_person,
  NULL::timestamptz AS configured_at,
  COALESCE(r.app_eui, '0000000000000000') AS app_eui,
  r.app_key,
  'device_test_registrations'::varchar(50) AS source_table
FROM system_schema.device_test_registrations r
WHERE r.so_number IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM traceability_manager.traceability_device td
    WHERE td.serial_number = COALESCE(r.serial_number, r.dev_eui)
       OR (td.dev_eui IS NOT NULL AND LOWER(td.dev_eui) = LOWER(r.dev_eui))
  );

COMMENT ON VIEW system_schema.v_so_tested_devices IS 'View hợp nhất thiết bị đã đo kiểm theo SO giữa traceability_device và device_test_registrations phục vụ Final Config';

-- Grant runtime permissions
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON system_schema.v_so_tested_devices TO itest_system_user;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON system_schema.v_so_tested_devices TO itest_plugins_user;
  END IF;

  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.v_so_tested_devices TO itest_ops_user;
  END IF;
END $$;
