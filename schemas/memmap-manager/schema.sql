-- ==============================================================================
-- ITEST PLATFORM - MEMMAP MANAGER PLUGIN SCHEMA (POSTGRESQL 17)
-- ==============================================================================
-- File: schemas/memmap-manager/schema.sql
-- Description: Entrypoint DDL for memmap_manager schema.
-- ==============================================================================

\ir migrations/001_create_memmap_manager_tables.sql
\ir migrations/002_grant_runtime_privileges.sql
\ir migrations/003_extend_memmap_registers_metadata.sql
\ir migrations/004_align_memmap_profiles_and_registers_to_human_spec.sql
\ir migrations/005_identify_by_item_code_and_fw_version.sql
\ir migrations/006_relax_fw_version_format_to_flexible_numeric.sql
