-- App EUI is read from LoRaWAN register 31 during device testing and persisted
-- in device_test_registrations. A memmap profile describes the register, not
-- the device-specific value.
DROP VIEW IF EXISTS traceability_manager.v_device_summary;
CREATE VIEW traceability_manager.v_device_summary AS
SELECT
  d.id AS device_id,
  d.serial_number,
  d.dev_eui,
  COALESCE(
    NULLIF(NULLIF(BTRIM(d.app_eui), ''), '0000000000000000'),
    NULLIF(NULLIF(BTRIM(d.test_raw_data->>'app_eui'), ''), '0000000000000000'),
    NULLIF(NULLIF(BTRIM(d.test_raw_data->>'appeui'), ''), '0000000000000000'),
    NULLIF(NULLIF(BTRIM(d.test_raw_data->'lorawan'->>'app_eui'), ''), '0000000000000000'),
    NULLIF(NULLIF(BTRIM(d.test_raw_data->'lorawan'->>'appeui'), ''), '0000000000000000'),
    NULLIF(NULLIF(BTRIM(d.test_raw_data->'comparison'->>'app_eui'), ''), '0000000000000000'),
    dtr.app_eui
  ) AS app_eui,
  COALESCE(
    d.app_key,
    d.test_raw_data->>'app_key',
    d.test_raw_data->'final_config_audit'->>'app_key',
    dtr.app_key
  ) AS app_key,
  COALESCE(d.item_code, wa.item_code) AS item_code,
  d.hw_version,
  d.fw_version,
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  so.partner_email,
  wa.id AS wa_id,
  wa.wa_number,
  d.test_result,
  d.test_id,
  d.test_station,
  d.test_person,
  d.tested_at,
  d.config_status,
  COALESCE(
    d.config_person,
    fcs.operator,
    d.test_raw_data->'final_config_audit'->>'operator',
    d.test_raw_data->'final_config_audit'->>'configured_by'
  ) AS config_person,
  COALESCE(
    d.configured_at,
    fcs.completed_at,
    (d.test_raw_data->'final_config_audit'->>'saved_at')::timestamptz
  ) AS configured_at,
  d.final_config_session_id,
  d.status AS overall_status,
  d.created_at,
  d.updated_at
FROM traceability_manager.traceability_device d
JOIN traceability_manager.traceability_so so ON d.so_id = so.id
LEFT JOIN traceability_manager.traceability_wa wa ON d.wa_id = wa.id
LEFT JOIN finalconfig_manager.finalconfig_execution_session fcs ON d.final_config_session_id = fcs.id
LEFT JOIN LATERAL (
  SELECT NULLIF(NULLIF(BTRIM(r.app_eui), ''), '0000000000000000') AS app_eui, r.app_key
  FROM system_schema.device_test_registrations r
  WHERE r.serial_number = d.serial_number
    AND (NULLIF(NULLIF(BTRIM(r.app_eui), ''), '0000000000000000') IS NOT NULL OR r.app_key IS NOT NULL)
  ORDER BY (NULLIF(NULLIF(BTRIM(r.app_eui), ''), '0000000000000000') IS NOT NULL) DESC, r.created_at DESC, r.id DESC
  LIMIT 1
) dtr ON true;

COMMENT ON VIEW traceability_manager.v_device_summary IS 'Metabase device tracking: App EUI from LoRaWAN register 31 (device testing registration); excludes device_key and sku.';
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON traceability_manager.v_device_summary TO itest_system_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON traceability_manager.v_device_summary TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT SELECT ON traceability_manager.v_device_summary TO itest_plugin_user;
  END IF;
END $$;
