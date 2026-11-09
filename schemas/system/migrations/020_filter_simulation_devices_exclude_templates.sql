-- ==============================================================================
-- MIGRATION: 020_filter_simulation_devices_exclude_templates.sql
-- Module: testing / system
-- Schema: system_schema
-- Target: v_simulation_devices
-- Description:
--   Update view system_schema.v_simulation_devices to ONLY include devices
--   with status = 'simulation'. Explicitly exclude template records so flow simulation
--   templates are never exposed as mock/phantom simulation devices.
-- ==============================================================================

SET search_path TO system_schema, public;

DO $$
BEGIN
  EXECUTE 'DROP VIEW IF EXISTS system_schema.v_simulation_devices CASCADE;';
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'devices' AND table_name = 'devices'
  ) THEN
    EXECUTE '
      CREATE OR REPLACE VIEW system_schema.v_simulation_devices AS
      SELECT
        d."id",
        d."serial_number",
        d."network_id",
        d."device_name",
        d."device_type",
        d."plugin_id",
        d."so_number",
        d."wa_number",
        d."item_code",
        d."status",
        d."metadata",
        d."created_at",
        d."updated_at"
      FROM system_schema."devices" d
      WHERE d."status" = ''simulation''
      UNION ALL
      SELECT
        dev."id",
        dev."serial_number",
        dev."network_id",
        dev."device_name",
        dev."device_type",
        dev."plugin_id",
        dev."so_number",
        dev."wa_number",
        dev."item_code",
        dev."status",
        dev."metadata",
        dev."created_at",
        dev."updated_at"
      FROM devices."devices" dev
      WHERE dev."status" = ''simulation''
        AND NOT EXISTS (
          SELECT 1 FROM system_schema."devices" sd WHERE sd."serial_number" = dev."serial_number"
        );
    ';
  ELSE
    EXECUTE '
      CREATE OR REPLACE VIEW system_schema.v_simulation_devices AS
      SELECT
        d."id",
        d."serial_number",
        d."network_id",
        d."device_name",
        d."device_type",
        d."plugin_id",
        d."so_number",
        d."wa_number",
        d."item_code",
        d."status",
        d."metadata",
        d."created_at",
        d."updated_at"
      FROM system_schema."devices" d
      WHERE d."status" = ''simulation'';
    ';
  END IF;
END $$;

COMMENT ON VIEW system_schema.v_simulation_devices IS 'View danh sách các thiết bị kiểm thử simulation thực tế (không bao gồm template)';

DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_system_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugins_user') THEN
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_plugins_user;
  END IF;
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_ops_user') THEN
    GRANT SELECT ON system_schema.v_simulation_devices TO itest_ops_user;
  END IF;
END $$;
