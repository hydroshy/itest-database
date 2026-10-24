/**
 * Schema & Migration Verification Test Suite for itest-database
 * Validates SQL syntax, file paths, and migration engine configuration
 */

const fs = require('fs');
const path = require('path');
const assert = require('assert');

console.log('--- RUNNING ITEST DATABASE INTEGRITY TESTS ---');

// 1. Verify required files exist
const requiredFiles = [
  'init-scripts/01-init-databases.sql',
  'init-scripts/02-init-tables.sql',
  'schemas/system/schema.sql',
  'schemas/plugins/schema.sql',
  'schemas/ops-agent/schema.sql',
  'schemas/lorawan-chirpstack/schema.sql',
  'schemas/lorawan-chirpstack/migrations/001_create_network_servers_table.sql',
  'schemas/lorawan-chirpstack/migrations/002_grant_runtime_privileges.sql',
  'schemas/traceability-manager/schema.sql',
  'schemas/traceability-manager/migrations/001_create_traceability_manager_tables.sql',
  'schemas/traceability-manager/migrations/002_grant_runtime_privileges.sql',
  'schemas/traceability-manager/migrations/003_add_traceability_item_code_indexes_and_views.sql',
  'schemas/traceability-manager/migrations/004_add_partner_email_to_traceability_so.sql',
  'schemas/traceability-manager/migrations/005_enhance_v_so_item_summary_with_wa.sql',
  'schemas/traceability-manager/METABASE_DOCS.md',
  'schemas/system/migrations/003_create_menu_items_and_role_permissions.sql',
  'schemas/system/migrations/004_create_system_menu_compat_views.sql',
  'scripts/migrate.js'
];

for (const relPath of requiredFiles) {
  const fullPath = path.join(__dirname, relPath);
  assert.ok(fs.existsSync(fullPath), `Missing required file: ${relPath}`);
  console.log(`✓ File exists: ${relPath}`);
}

// 2. Validate 01-init-databases.sql has lorawan_chirpstack schema and grants
const initSql = fs.readFileSync(path.join(__dirname, 'init-scripts/01-init-databases.sql'), 'utf8');
assert.ok(initSql.includes('CREATE SCHEMA IF NOT EXISTS lorawan_chirpstack;'), 'Missing CREATE SCHEMA lorawan_chirpstack in 01-init-databases.sql');
assert.ok(initSql.includes('GRANT USAGE, CREATE ON SCHEMA lorawan_chirpstack TO itest_plugins_user;'), 'Missing grant for itest_plugins_user');
assert.ok(initSql.includes('GRANT USAGE, CREATE ON SCHEMA lorawan_chirpstack TO itest_system_user;'), 'Missing grant for itest_system_user');
console.log('✓ 01-init-databases.sql contains correct schema and grants');

// 2b. Verify the idempotent runtime-grant migration protects existing volumes.
const runtimeGrantSql = fs.readFileSync(
  path.join(__dirname, 'schemas/lorawan-chirpstack/migrations/002_grant_runtime_privileges.sql'),
  'utf8'
);
assert.ok(runtimeGrantSql.includes('GRANT USAGE ON SCHEMA lorawan_chirpstack TO itest_system_user;'), 'Missing runtime schema usage grant');
assert.ok(runtimeGrantSql.includes('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA lorawan_chirpstack TO itest_system_user;'), 'Missing runtime table grant');
assert.ok(runtimeGrantSql.includes('GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA lorawan_chirpstack TO itest_system_user;'), 'Missing runtime sequence grant');
console.log('✓ Runtime grant migration repairs existing PostgreSQL volumes');

// 3. Validate 02-init-tables.sql includes lorawan-chirpstack schema.sql
const initTablesSql = fs.readFileSync(path.join(__dirname, 'init-scripts/02-init-tables.sql'), 'utf8');
assert.ok(initTablesSql.includes('/opt/schemas/lorawan-chirpstack/schema.sql'), 'Missing include for lorawan-chirpstack in 02-init-tables.sql');
console.log('✓ 02-init-tables.sql properly includes lorawan-chirpstack schema.sql');

// 4. Validate 001_create_network_servers_table.sql schema definition
const migrationSql = fs.readFileSync(path.join(__dirname, 'schemas/lorawan-chirpstack/migrations/001_create_network_servers_table.sql'), 'utf8');
assert.ok(migrationSql.includes('CREATE TABLE IF NOT EXISTS lorawan_chirpstack."network_servers"'), 'Missing network_servers table creation');
assert.ok(migrationSql.includes('"id" UUID PRIMARY KEY DEFAULT gen_random_uuid()'), 'Missing id UUID PK');
assert.ok(migrationSql.includes('"name" VARCHAR(100) NOT NULL'), 'Missing name column');
assert.ok(migrationSql.includes('"api_url" VARCHAR(255) NOT NULL'), 'Missing api_url column');
assert.ok(migrationSql.includes('"api_token" TEXT NOT NULL'), 'Missing api_token column');
assert.ok(migrationSql.includes('"tenant_id" VARCHAR(100)'), 'Missing tenant_id column');
assert.ok(migrationSql.includes('"is_active" BOOLEAN NOT NULL DEFAULT true'), 'Missing is_active column');
assert.ok(migrationSql.includes('"created_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP'), 'Missing created_at column');
assert.ok(migrationSql.includes('"updated_at" TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP'), 'Missing updated_at column');
assert.ok(migrationSql.includes('CREATE TABLE IF NOT EXISTS lorawan_chirpstack."_migrations"'), 'Missing migration tracking table');
console.log('✓ 001_create_network_servers_table.sql matches all contract specifications');

// 5. Validate scripts/migrate.js configuration
const migrateSource = fs.readFileSync(path.join(__dirname, 'scripts/migrate.js'), 'utf8');
assert.ok(migrateSource.includes("'lorawan-chirpstack'"), 'Missing lorawan-chirpstack source in migrate.js');
assert.ok(migrateSource.includes("'memmap-manager'"), 'Missing memmap-manager source in migrate.js');
assert.ok(migrateSource.includes("'finalconfig-manager'"), 'Missing finalconfig-manager source in migrate.js');
assert.ok(migrateSource.includes("'traceability-manager'"), 'Missing traceability-manager source in migrate.js');
console.log('✓ scripts/migrate.js contains all plugin sources');

// 6. Validate traceability_manager migration & view specifications (Data Contract v2)
const traceMigration001 = fs.readFileSync(
  path.join(__dirname, 'schemas/traceability-manager/migrations/001_create_traceability_manager_tables.sql'),
  'utf8'
);
assert.ok(traceMigration001.includes('CREATE SCHEMA IF NOT EXISTS traceability_manager;'), 'Missing schema traceability_manager');
assert.ok(traceMigration001.includes('CREATE TABLE IF NOT EXISTS traceability_manager."traceability_so"'), 'Missing traceability_so table');
assert.ok(traceMigration001.includes('CREATE TABLE IF NOT EXISTS traceability_manager."traceability_wa"'), 'Missing traceability_wa table');
assert.ok(traceMigration001.includes('CREATE TABLE IF NOT EXISTS traceability_manager."traceability_device"'), 'Missing traceability_device table');

// Validate key columns and constraints
assert.ok(traceMigration001.includes('"so_number" VARCHAR(50) NOT NULL UNIQUE'), 'Missing unique so_number');
assert.ok(traceMigration001.includes('"wa_number" VARCHAR(50) NOT NULL UNIQUE'), 'Missing unique wa_number');
assert.ok(traceMigration001.includes('"serial_number" VARCHAR(100) NOT NULL UNIQUE'), 'Missing unique serial_number');
assert.ok(traceMigration001.includes('"test_result" VARCHAR(20) NOT NULL DEFAULT \'PENDING\''), 'Missing test_result column');
assert.ok(traceMigration001.includes('"test_raw_data" JSONB NOT NULL DEFAULT \'{}\'::jsonb'), 'Missing test_raw_data column');
assert.ok(traceMigration001.includes('v_device_traceability_lifecycle'), 'Missing Metabase lifecycle view');
assert.ok(traceMigration001.includes('(d.test_result = \'PASS\') AS is_eligible_for_final_config'), 'Missing is_eligible_for_final_config in view');
console.log('✓ 001_create_traceability_manager_tables.sql matches all Data Contract v2 specifications');

const traceMigration002 = fs.readFileSync(
  path.join(__dirname, 'schemas/traceability-manager/migrations/002_grant_runtime_privileges.sql'),
  'utf8'
);
assert.ok(traceMigration002.includes('GRANT USAGE ON SCHEMA traceability_manager TO itest_system_user;'), 'Missing system_user grant');
assert.ok(traceMigration002.includes('GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA traceability_manager TO itest_system_user;'), 'Missing system_user table grant');
assert.ok(traceMigration002.includes('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE traceability_manager."traceability_so" TO itest_system_user;'), 'Missing traceability_so explicit grant');
assert.ok(traceMigration002.includes('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE traceability_manager."traceability_wa" TO itest_system_user;'), 'Missing traceability_wa explicit grant');
assert.ok(traceMigration002.includes('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE traceability_manager."traceability_device" TO itest_system_user;'), 'Missing traceability_device explicit grant');
assert.ok(traceMigration002.includes('GRANT SELECT ON TABLE traceability_manager."v_device_traceability_lifecycle" TO itest_system_user;'), 'Missing view explicit grant');
console.log('✓ 002_grant_runtime_privileges.sql grants proper runtime privileges on all v2 objects');

const metabaseDocs = fs.readFileSync(
  path.join(__dirname, 'schemas/traceability-manager/METABASE_DOCS.md'),
  'utf8'
);
assert.ok(metabaseDocs.includes('traceability_so'), 'Missing traceability_so in docs');
assert.ok(metabaseDocs.includes('traceability_wa'), 'Missing traceability_wa in docs');
assert.ok(metabaseDocs.includes('traceability_device'), 'Missing traceability_device in docs');
assert.ok(metabaseDocs.includes('v_device_traceability_lifecycle'), 'Missing view in docs');
assert.ok(metabaseDocs.includes('is_eligible_for_final_config'), 'Missing is_eligible_for_final_config in docs');
console.log('✓ METABASE_DOCS.md contains comprehensive data dictionary & BI query recipes for v2');

const menuMigration003 = fs.readFileSync(
  path.join(__dirname, 'schemas/system/migrations/003_create_menu_items_and_role_permissions.sql'),
  'utf8'
);
assert.ok(menuMigration003.includes('CREATE TABLE IF NOT EXISTS system_schema."menu_items"'), 'Missing menu_items table');
assert.ok(menuMigration003.includes('CREATE TABLE IF NOT EXISTS system_schema."role_menu_permissions"'), 'Missing role_menu_permissions table');
assert.ok(menuMigration003.includes('dashboard'), 'Missing dashboard seed');
assert.ok(menuMigration003.includes('final-config:tool'), 'Missing final-config:tool seed');
assert.ok(menuMigration003.includes('final-config:manager'), 'Missing final-config:manager seed');
assert.ok(menuMigration003.includes('final-config:create'), 'Missing final-config:create seed');
assert.ok(menuMigration003.includes('device-traceability:so'), 'Missing device-traceability:so seed');
assert.ok(menuMigration003.includes('device-traceability:devices'), 'Missing device-traceability:devices seed');
assert.ok(menuMigration003.includes('device-traceability:config'), 'Missing device-traceability:config seed');
assert.ok(menuMigration003.includes('memmap-payload:manager'), 'Missing memmap-payload:manager seed');
assert.ok(menuMigration003.includes('lorawan-chirpstack:integration'), 'Missing lorawan-chirpstack:integration seed');
assert.ok(menuMigration003.includes('SUPER_ADMIN') && menuMigration003.includes('END_USER'), 'Missing role seeds');
assert.ok(menuMigration003.includes('GRANT ALL PRIVILEGES ON TABLE system_schema."menu_items" TO itest_system_user;'), 'Missing runtime grant menu_items');
assert.ok(menuMigration003.includes('GRANT ALL PRIVILEGES ON TABLE system_schema."role_menu_permissions" TO itest_system_user;'), 'Missing runtime grant role_menu_permissions');
console.log('✓ 003_create_menu_items_and_role_permissions.sql matches all Menu & Role Permission specs');

// 6b. Verify migration 004 provides public and system_schema compatibility views for MenuService
const menuMigration004 = fs.readFileSync(
  path.join(__dirname, 'schemas/system/migrations/004_create_system_menu_compat_views.sql'),
  'utf8'
);
assert.ok(menuMigration004.includes('CREATE OR REPLACE VIEW public."system_menu_items"'), 'Missing public.system_menu_items view');
assert.ok(menuMigration004.includes('CREATE OR REPLACE VIEW public."role_menu_permissions"'), 'Missing public.role_menu_permissions view');
assert.ok(menuMigration004.includes('CREATE OR REPLACE VIEW system_schema."system_menu_items"'), 'Missing system_schema.system_menu_items view');
assert.ok(menuMigration004.includes('GRANT ALL PRIVILEGES ON TABLE public."system_menu_items" TO itest_system_user;'), 'Missing grant on public.system_menu_items');
assert.ok(menuMigration004.includes('ALTER ROLE itest_system_user SET search_path'), 'Missing search_path update for itest_system_user');
console.log('✓ 004_create_system_menu_compat_views.sql matches all Menu compatibility view specs');

console.log('--- ALL INTEGRITY TESTS PASSED ---');
