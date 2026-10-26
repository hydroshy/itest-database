-- ==============================================================================
-- ITEST PLATFORM - LORAWAN CHIRPSTACK PLUGIN SCHEMA (POSTGRESQL 17)
-- ==============================================================================
-- File: schemas/lorawan-chirpstack/schema.sql
-- Description: Entrypoint DDL for lorawan_chirpstack schema. Executes all modular
--              migrations sequentially for initial setup and upgrades.
-- ==============================================================================

\i /opt/schemas/lorawan-chirpstack/migrations/001_create_network_servers_table.sql
\i /opt/schemas/lorawan-chirpstack/migrations/002_grant_runtime_privileges.sql
\i /opt/schemas/lorawan-chirpstack/migrations/003_create_gateway_test_sessions.sql
