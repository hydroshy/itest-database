-- ==============================================================================
-- ITEST PLATFORM - MEMMAP MANAGER PLUGIN SCHEMA (POSTGRESQL 17)
-- ==============================================================================
-- File: schemas/memmap-manager/schema.sql
-- Description: Entrypoint DDL for memmap_manager schema.
-- ==============================================================================

\i /opt/schemas/memmap-manager/migrations/001_create_memmap_manager_tables.sql
\i /opt/schemas/memmap-manager/migrations/002_grant_runtime_privileges.sql
