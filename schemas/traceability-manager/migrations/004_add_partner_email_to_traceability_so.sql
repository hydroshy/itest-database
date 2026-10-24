-- ==============================================================================
-- MIGRATION: 004_add_partner_email_to_traceability_so.sql
-- Module: traceability-manager
-- Schema: traceability_manager
-- Description: Add partner_email and customer_email columns to traceability_so
--              and update analytical views safely with DROP VIEW CASCADE.
-- ==============================================================================

-- 1. Add email columns to traceability_so
ALTER TABLE traceability_manager."traceability_so"
  ADD COLUMN IF NOT EXISTS "partner_email" VARCHAR(255);

ALTER TABLE traceability_manager."traceability_so"
  ADD COLUMN IF NOT EXISTS "customer_email" VARCHAR(255);

COMMENT ON COLUMN traceability_manager."traceability_so"."partner_email" IS 'Email của đối tác / khách hàng liên hệ từ SO (DIS partner_email)';
COMMENT ON COLUMN traceability_manager."traceability_so"."customer_email" IS 'Alias email khách hàng (tương thích ngược)';

-- 2. Drop existing tree analytical view before recreate to avoid PostgreSQL 42P16 error
DROP VIEW IF EXISTS traceability_manager.v_so_item_summary CASCADE;

-- 3. Recreate analytical view v_so_item_summary
CREATE OR REPLACE VIEW traceability_manager.v_so_item_summary AS
SELECT
  so.id AS so_id,
  so.so_number,
  so.customer_name,
  so.partner_email,
  COALESCE(d.item_code, 'UNKNOWN') AS item_code,
  COUNT(d.id) AS total_tested_serials,
  COUNT(d.id) FILTER (WHERE d.test_result = 'PASS') AS passed_serials,
  COUNT(d.id) FILTER (WHERE d.test_result = 'FAIL') AS failed_serials,
  MIN(d.tested_at) AS first_tested_at,
  MAX(d.tested_at) AS last_tested_at
FROM traceability_manager."traceability_so" so
JOIN traceability_manager."traceability_device" d ON d.so_id = so.id
GROUP BY so.id, so.so_number, so.customer_name, so.partner_email, COALESCE(d.item_code, 'UNKNOWN');

COMMENT ON VIEW traceability_manager.v_so_item_summary IS 'Analytical View for Tree Structure: Aggregates serial count and test results grouped by SO, Partner Email, and Item Code.';

-- 4. Conditionally update v_device_traceability_lifecycle if finalconfig table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'finalconfig_manager' AND table_name = 'finalconfig_execution_session'
  ) THEN
    DROP VIEW IF EXISTS traceability_manager.v_device_traceability_lifecycle CASCADE;
    EXECUTE '
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
        d.test_raw_data,
        (d.test_result = ''PASS'') AS is_eligible_for_final_config,
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
    ';
    IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
      EXECUTE 'GRANT SELECT ON TABLE traceability_manager.v_device_traceability_lifecycle TO itest_system_user';
    END IF;
    IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
      EXECUTE 'GRANT SELECT ON TABLE traceability_manager.v_device_traceability_lifecycle TO itest_plugin_user';
    END IF;
  END IF;
END $$;

-- 5. Grants for runtime roles on v_so_item_summary
DO $$
BEGIN
  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_system_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_item_summary TO itest_system_user;
  END IF;

  IF EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'itest_plugin_user') THEN
    GRANT SELECT ON TABLE traceability_manager.v_so_item_summary TO itest_plugin_user;
  END IF;
END $$;
