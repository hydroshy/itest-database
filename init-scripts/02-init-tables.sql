-- ==============================================================================
-- ITEST PLATFORM - AUTO INITIALIZE ALL SCHEMAS AND TABLES (POSTGRESQL 17)
-- ==============================================================================
-- File: init-scripts/02-init-tables.sql
-- Description: Auto-executes DDL for system_schema, plugins_schema, and ops_schema
--              when PostgreSQL container starts for the first time.
-- ==============================================================================

\i /opt/schemas/system/schema.sql
\i /opt/schemas/plugins/schema.sql
\i /opt/schemas/ops-agent/schema.sql
\i /opt/schemas/lorawan-chirpstack/schema.sql
\i /opt/schemas/memmap-manager/schema.sql
\i /opt/schemas/finalconfig-manager/schema.sql
\i /opt/schemas/traceability-manager/schema.sql
