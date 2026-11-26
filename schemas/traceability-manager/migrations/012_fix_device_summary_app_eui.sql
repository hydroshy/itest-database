-- ==============================================================================
-- MIGRATION: 012_fix_device_summary_app_eui.sql
-- Module: traceability-manager
-- Schema: traceability_manager
-- Description: v_device_summary gets AppEUI readback from Final Config:
--              1. Prioritizes Final Config execution log / audit readback on
--                 register 31 (LoRaWAN App EUI / 0x001F).
--              2. Fallback to traceability_device, test_raw_data, or registration.
--              3. Excludes device_key and sku columns.
--              4. Does not default to fake '0000000000000000'.
-- ==============================================================================

DROP VIEW IF EXISTS traceability_manager.v_device_summary CASCADE;

CREATE OR REPLACE VIEW traceability_manager.v_device_summary AS
SELECT
  d.id AS device_id,
  d.serial_number,
  d.dev_eui,
  COALESCE(
    -- 1. Readback from Final Config execution log (register 31: LoRaWAN App EUI)
    fcl.read_app_eui,
    -- 2. Readback from Final Config audit snapshot in test_raw_data JSONB
    NULLIF(NULLIF(BTRIM(d.test_raw_data->'final_config_audit'->'metadata'->'traceability'->>'app_eui'), ''), '0000000000000000'),
    fca.audit_read_app_eui,
    -- 3. Device record / test raw data
    NULLIF(NULLIF(BTRIM(d.app_eui), ''), '0000000000000000'),
    NULLIF(NULLIF(BTRIM(d.test_raw_data->>'app_eui'), ''), '0000000000000000'),
    NULLIF(NULLIF(BTRIM(d.test_raw_data->>'appeui'), ''), '0000000000000000'),
    NULLIF(NULLIF(BTRIM(d.test_raw_data->'lorawan'->>'app_eui'), ''), '0000000000000000'),
    NULLIF(NULLIF(BTRIM(d.test_raw_data->'lorawan'->>'appeui'), ''), '0000000000000000'),
    NULLIF(NULLIF(BTRIM(d.test_raw_data->'comparison'->>'app_eui'), ''), '0000000000000000'),
    -- 4. Fallback to testing registration
    dtr.app_eui
  ) AS app_eui,
  COALESCE(
    d.app_key,
    d.test_raw_data->>'app_key',
    d.test_raw_data->'final_config_audit'->>'app_key',
    fcs.metadata->>'app_key',
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
  SELECT
    NULLIF(NULLIF(BTRIM(COALESCE(l.raw_hex, l.read_value)), ''), '0000000000000000') AS read_app_eui
  FROM finalconfig_manager.finalconfig_execution_log l
  WHERE l.session_id = d.final_config_session_id
    AND l.modbus_register_dec = 31
    AND NULLIF(NULLIF(BTRIM(COALESCE(l.raw_hex, l.read_value)), ''), '0000000000000000') IS NOT NULL
  ORDER BY l.created_at DESC, l.id DESC
  LIMIT 1
) fcl ON true
LEFT JOIN LATERAL (
  SELECT
    NULLIF(NULLIF(BTRIM(reg->>'value_read_back'), ''), '0000000000000000') AS audit_read_app_eui
  FROM jsonb_array_elements(
    CASE
      WHEN jsonb_typeof(d.test_raw_data->'final_config_audit'->'registers') = 'array'
      THEN d.test_raw_data->'final_config_audit'->'registers'
      ELSE '[]'::jsonb
    END
  ) AS reg
  WHERE (reg->>'address' = '31' OR reg->>'parameter_name' ILIKE '%App%EUI%')
    AND NULLIF(NULLIF(BTRIM(reg->>'value_read_back'), ''), '0000000000000000') IS NOT NULL
  LIMIT 1
) fca ON true
LEFT JOIN LATERAL (
  SELECT NULLIF(NULLIF(BTRIM(r.app_eui), ''), '0000000000000000') AS app_eui, r.app_key
  FROM system_schema.device_test_registrations r
  WHERE r.serial_number = d.serial_number
    AND (NULLIF(NULLIF(BTRIM(r.app_eui), ''), '0000000000000000') IS NOT NULL OR r.app_key IS NOT NULL)
  ORDER BY (NULLIF(NULLIF(BTRIM(r.app_eui), ''), '0000000000000000') IS NOT NULL) DESC, r.created_at DESC, r.id DESC
  LIMIT 1
) dtr ON true;

COMMENT ON VIEW traceability_manager.v_device_summary IS 'Metabase Analytical View: Comprehensive device tracking view exposing dev_eui, app_key, app_eui (readback from final config register 31), serial_number, hardware test results, and final config details.';

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_device_summary TO itest_system_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_device_summary TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_device_summary TO itest_plugin_user;
  END IF;
END $$;
