-- ==============================================================================
-- ITEST PLATFORM - LORAWAN CHIRPSTACK PLUGIN SCHEMA (POSTGRESQL 17)
-- ==============================================================================
-- File: schemas/lorawan-chirpstack/schema.sql
-- Description: Entrypoint DDL for lorawan_chirpstack schema. Executes all modular
--              migrations sequentially for initial setup and upgrades.
-- ==============================================================================

\ir migrations/001_create_network_servers_table.sql
\ir migrations/002_grant_runtime_privileges.sql
\ir migrations/003_create_gateway_test_sessions.sql
\ir migrations/004_extend_gateway_test_sessions_metadata.sql
\ir migrations/005_add_app_and_device_profile_to_network_servers.sql


