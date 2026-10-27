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
  'schemas/system/migrations/005_create_testing_devices_and_packets_tables.sql',
  'schemas/lorawan-chirpstack/migrations/003_create_gateway_test_sessions.sql',
  'schemas/plugins/migrations/001_create_decoder_scripts_and_views.sql',
  'schemas/decoder/schema.sql',
  'schemas/decoder/migrations/001_create_decoder_schema_and_tables.sql',
  'schemas/decoder/migrations/002_add_name_column_to_decoder_scripts.sql',
  'schemas/devices/schema.sql',
  'schemas/devices/migrations/001_create_devices_schema_and_tables.sql',
  'schemas/devices/migrations/002_add_device_id_and_gateway_name_columns.sql',
  'schemas/devices/migrations/003_add_device_serial_number_and_traceability_columns.sql',
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
assert.ok(initSql.includes('GRANT USAGE, CREATE ON SCHEMA plugins_schema TO itest_system_user;'), 'Missing grant on plugins_schema for itest_system_user');
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

// 8. Validate system migration 005 (devices & device_packets for testing plugin)
const systemMig005 = fs.readFileSync(
  path.join(__dirname, 'schemas/system/migrations/005_create_testing_devices_and_packets_tables.sql'),
  'utf8'
);
assert.ok(systemMig005.includes('CREATE TABLE IF NOT EXISTS system_schema."devices"'), 'Missing devices table in system migration 005');
assert.ok(systemMig005.includes('CREATE TABLE IF NOT EXISTS system_schema."device_packets"'), 'Missing device_packets table in system migration 005');
assert.ok(systemMig005.includes('"serial_number" VARCHAR(100) NOT NULL UNIQUE'), 'Missing serial_number column in devices');
assert.ok(systemMig005.includes('"network_id" VARCHAR(100)'), 'Missing network_id column in devices');
assert.ok(systemMig005.includes('"plugin_id" VARCHAR(128) NOT NULL DEFAULT \'testing\''), 'Missing plugin_id column in devices');
assert.ok(systemMig005.includes('"so_number" VARCHAR(100)'), 'Missing so_number column in devices');
assert.ok(systemMig005.includes('"wa_number" VARCHAR(100)'), 'Missing wa_number column in devices');
assert.ok(systemMig005.includes('"item_code" VARCHAR(100)'), 'Missing item_code column in devices');
assert.ok(systemMig005.includes('"raw_payload" TEXT'), 'Missing raw_payload in device_packets');
assert.ok(systemMig005.includes('"decoded_payload" JSONB NOT NULL DEFAULT \'{}\'::jsonb'), 'Missing decoded_payload JSONB in device_packets');
assert.ok(systemMig005.includes('"rf_info" JSONB NOT NULL DEFAULT \'{}\'::jsonb'), 'Missing rf_info JSONB in device_packets');
assert.ok(systemMig005.includes('CREATE OR REPLACE VIEW system_schema.v_devices_traceability'), 'Missing v_devices_traceability view');
console.log('✓ 005_create_testing_devices_and_packets_tables.sql matches all Testing Plugin specifications');

// 9. Validate lorawan migration 003 (gateway_test_sessions)
const lorawanMig003 = fs.readFileSync(
  path.join(__dirname, 'schemas/lorawan-chirpstack/migrations/003_create_gateway_test_sessions.sql'),
  'utf8'
);
assert.ok(lorawanMig003.includes('CREATE TABLE IF NOT EXISTS lorawan_chirpstack."gateway_test_sessions"'), 'Missing gateway_test_sessions table');
assert.ok(lorawanMig003.includes('"gateway_id" VARCHAR(64) NOT NULL'), 'Missing gateway_id column');
assert.ok(lorawanMig003.includes('"status" VARCHAR(50) NOT NULL DEFAULT \'IN_PROGRESS\''), 'Missing status column');
assert.ok(lorawanMig003.includes('"summary" JSONB NOT NULL DEFAULT \'{}\'::jsonb'), 'Missing summary JSONB column');
console.log('✓ 003_create_gateway_test_sessions.sql matches Gateway test flow specifications');

// 10. Validate plugins decoder migration 001 (decoder_scripts & v_memmap_decoders)
const decoderMig001 = fs.readFileSync(
  path.join(__dirname, 'schemas/plugins/migrations/001_create_decoder_scripts_and_views.sql'),
  'utf8'
);
assert.ok(decoderMig001.includes('CREATE TABLE IF NOT EXISTS plugins_schema."decoder_scripts"'), 'Missing decoder_scripts table');
assert.ok(decoderMig001.includes('"sku" VARCHAR(100) NOT NULL'), 'Missing sku in decoder_scripts');
assert.ok(decoderMig001.includes('"long_fw" VARCHAR(100) NOT NULL'), 'Missing long_fw in decoder_scripts');
assert.ok(decoderMig001.includes('"protocol" VARCHAR(50) NOT NULL DEFAULT \'lorawan\''), 'Missing protocol in decoder_scripts');
assert.ok(decoderMig001.includes('"script" TEXT NOT NULL'), 'Missing script in decoder_scripts');
assert.ok(decoderMig001.includes('"input_format" VARCHAR(50) NOT NULL DEFAULT \'hex\''), 'Missing input_format in decoder_scripts');
assert.ok(decoderMig001.includes('"sample_payload" TEXT'), 'Missing sample_payload in decoder_scripts');
assert.ok(decoderMig001.includes('"sample_fport" INTEGER NOT NULL DEFAULT 1'), 'Missing sample_fport in decoder_scripts');
assert.ok(decoderMig001.includes('"sample_decoded" JSONB DEFAULT \'{}\'::jsonb'), 'Missing sample_decoded JSONB in decoder_scripts');
assert.ok(decoderMig001.includes('"is_active" BOOLEAN NOT NULL DEFAULT true'), 'Missing is_active in decoder_scripts');
assert.ok(decoderMig001.includes('CONSTRAINT "UQ_decoder_scripts_sku_long_fw" UNIQUE ("sku", "long_fw")'), 'Missing UNIQUE(sku, long_fw) constraint');
assert.ok(decoderMig001.includes('CREATE OR REPLACE VIEW plugins_schema.v_memmap_decoders'), 'Missing v_memmap_decoders view');
assert.ok(decoderMig001.includes('COALESCE(mp.sku, ds.sku) AS sku'), 'Missing COALESCE sku in v_memmap_decoders');
assert.ok(decoderMig001.includes('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE plugins_schema."decoder_scripts" TO itest_system_user;'), 'Missing grant on decoder_scripts for itest_system_user');
assert.ok(decoderMig001.includes('GRANT ALL PRIVILEGES ON TABLE plugins_schema."decoder_scripts" TO itest_plugins_user;'), 'Missing grant on decoder_scripts for itest_plugins_user');

const pluginsSchemaSql = fs.readFileSync(path.join(__dirname, 'schemas/plugins/schema.sql'), 'utf8');
assert.ok(pluginsSchemaSql.includes('CREATE TABLE IF NOT EXISTS plugins_schema."decoder_scripts"'), 'Missing decoder_scripts in schema.sql');
assert.ok(pluginsSchemaSql.includes('CREATE OR REPLACE VIEW plugins_schema.v_memmap_decoders'), 'Missing v_memmap_decoders in schema.sql');
console.log('✓ 001_create_decoder_scripts_and_views.sql & schemas/plugins/schema.sql match Plugin Decoder specifications');

// 11. Validate dedicated 'decoder' schema and migration
const decoderMigrationSql = fs.readFileSync(path.join(__dirname, 'schemas/decoder/migrations/001_create_decoder_schema_and_tables.sql'), 'utf8');
assert.ok(decoderMigrationSql.includes('CREATE SCHEMA IF NOT EXISTS decoder;'), 'Missing CREATE SCHEMA decoder');
assert.ok(decoderMigrationSql.includes('CREATE TABLE IF NOT EXISTS decoder.decoder_scripts'), 'Missing decoder.decoder_scripts table');
assert.ok(decoderMigrationSql.includes('CREATE OR REPLACE VIEW decoder.v_memmap_decoders'), 'Missing decoder.v_memmap_decoders view');
assert.ok(decoderMigrationSql.includes('CREATE OR REPLACE VIEW plugins_schema.decoder_scripts'), 'Missing plugins_schema.decoder_scripts compatibility view');
assert.ok(decoderMigrationSql.includes('CREATE OR REPLACE VIEW plugins_schema.v_memmap_decoders'), 'Missing plugins_schema.v_memmap_decoders compatibility view');

const decoderSchemaSql = fs.readFileSync(path.join(__dirname, 'schemas/decoder/schema.sql'), 'utf8');
assert.ok(decoderSchemaSql.includes('CREATE SCHEMA IF NOT EXISTS decoder;'), 'Missing CREATE SCHEMA in decoder/schema.sql');
assert.ok(decoderSchemaSql.includes('CREATE TABLE IF NOT EXISTS decoder.decoder_scripts'), 'Missing decoder.decoder_scripts in decoder/schema.sql');
assert.ok(decoderSchemaSql.includes('name VARCHAR(255)'), 'Missing name in decoder/schema.sql');
assert.ok(decoderSchemaSql.includes('CREATE OR REPLACE VIEW decoder.v_memmap_decoders'), 'Missing decoder.v_memmap_decoders in decoder/schema.sql');

// 11b. Validate migration 002 for decoder schema (name column, backfill, trigger, indexes, views)
const decoderMigration002Sql = fs.readFileSync(path.join(__dirname, 'schemas/decoder/migrations/002_add_name_column_to_decoder_scripts.sql'), 'utf8');
assert.ok(decoderMigration002Sql.includes('name VARCHAR(255)'), 'Missing name column in decoder migration 002');
assert.ok(decoderMigration002Sql.includes('decoder.sync_decoder_script_name()'), 'Missing sync_decoder_script_name trigger in decoder migration 002');
assert.ok(decoderMigration002Sql.includes('CREATE INDEX IF NOT EXISTS idx_decoder_name'), 'Missing idx_decoder_name in decoder migration 002');
assert.ok(decoderMigration002Sql.includes('CREATE OR REPLACE VIEW decoder.v_memmap_decoders'), 'Missing decoder.v_memmap_decoders view in decoder migration 002');
assert.ok(decoderMigration002Sql.includes('CREATE VIEW plugins_schema.decoder_scripts'), 'Missing plugins_schema.decoder_scripts view in decoder migration 002');
console.log('✓ Dedicated decoder schema, table, views, migration 002 and compatibility views validated');

// 12. Validate dedicated 'devices' schema and migration
const devicesMigrationSql = fs.readFileSync(path.join(__dirname, 'schemas/devices/migrations/001_create_devices_schema_and_tables.sql'), 'utf8');
assert.ok(devicesMigrationSql.includes('CREATE SCHEMA IF NOT EXISTS devices;'), 'Missing CREATE SCHEMA devices');
assert.ok(devicesMigrationSql.includes('CREATE TABLE IF NOT EXISTS devices.devices'), 'Missing devices.devices table');
assert.ok(devicesMigrationSql.includes('CREATE TABLE IF NOT EXISTS devices.gateway_test_sessions'), 'Missing devices.gateway_test_sessions table');
assert.ok(devicesMigrationSql.includes('CREATE TABLE IF NOT EXISTS devices.device_packets'), 'Missing devices.device_packets table');
assert.ok(devicesMigrationSql.includes('CREATE OR REPLACE VIEW devices.testing_devices'), 'Missing devices.testing_devices compatibility view');
assert.ok(devicesMigrationSql.includes('CREATE OR REPLACE VIEW devices.testing_packets'), 'Missing devices.testing_packets compatibility view');
assert.ok(devicesMigrationSql.includes('CREATE OR REPLACE VIEW system_schema.devices'), 'Missing system_schema.devices view');
assert.ok(devicesMigrationSql.includes('CREATE OR REPLACE VIEW system_schema.device_packets'), 'Missing system_schema.device_packets view');
assert.ok(devicesMigrationSql.includes('CREATE OR REPLACE VIEW lorawan_chirpstack.gateway_test_sessions'), 'Missing lorawan_chirpstack.gateway_test_sessions view');

const devicesSchemaSql = fs.readFileSync(path.join(__dirname, 'schemas/devices/schema.sql'), 'utf8');
assert.ok(devicesSchemaSql.includes('CREATE SCHEMA IF NOT EXISTS devices;'), 'Missing CREATE SCHEMA in devices/schema.sql');
assert.ok(devicesSchemaSql.includes('CREATE TABLE IF NOT EXISTS devices.devices'), 'Missing devices.devices in devices/schema.sql');
assert.ok(devicesSchemaSql.includes('CREATE TABLE IF NOT EXISTS devices.gateway_test_sessions'), 'Missing devices.gateway_test_sessions in devices/schema.sql');
assert.ok(devicesSchemaSql.includes('CREATE TABLE IF NOT EXISTS devices.device_packets'), 'Missing devices.device_packets in devices/schema.sql');

// 12b. Validate migration 002 for devices schema (device_id, raw_payload, decoded_payload, rf_info, gateway_name, etc.)
const devicesMigration002Sql = fs.readFileSync(path.join(__dirname, 'schemas/devices/migrations/002_add_device_id_and_gateway_name_columns.sql'), 'utf8');
assert.ok(devicesMigration002Sql.includes('gateway_name'), 'Missing gateway_name in migration 002');
assert.ok(devicesMigration002Sql.includes('started_at'), 'Missing started_at in migration 002');
assert.ok(devicesMigration002Sql.includes('ended_at'), 'Missing ended_at in migration 002');
assert.ok(devicesMigration002Sql.includes('summary'), 'Missing summary in migration 002');
assert.ok(devicesMigration002Sql.includes('device_id UUID'), 'Missing device_id UUID in migration 002');
assert.ok(devicesMigration002Sql.includes('raw_payload TEXT'), 'Missing raw_payload TEXT in migration 002');
assert.ok(devicesMigration002Sql.includes('decoded_payload JSONB'), 'Missing decoded_payload JSONB in migration 002');
assert.ok(devicesMigration002Sql.includes('rf_info JSONB'), 'Missing rf_info JSONB in migration 002');
assert.ok(devicesMigration002Sql.includes('packet_type VARCHAR'), 'Missing packet_type in migration 002');
assert.ok(devicesMigration002Sql.includes('devices.sync_device_packets_columns()'), 'Missing sync_device_packets_columns trigger');
assert.ok(devicesMigration002Sql.includes('devices.sync_gateway_test_sessions_columns()'), 'Missing sync_gateway_test_sessions_columns trigger');
console.log('✓ Dedicated devices schema, tables, indexes, migration 002 and compatibility views validated');

// 12c. Validate migration 003 for devices schema (serial_number, network_id, device_name, device_type, plugin_id, so_id, so_number, wa_id, wa_number, item_code, trigger, views)
const devicesMigration003Sql = fs.readFileSync(path.join(__dirname, 'schemas/devices/migrations/003_add_device_serial_number_and_traceability_columns.sql'), 'utf8');
assert.ok(devicesMigration003Sql.includes('serial_number VARCHAR(100)'), 'Missing serial_number in migration 003');
assert.ok(devicesMigration003Sql.includes('network_id VARCHAR(100)'), 'Missing network_id in migration 003');
assert.ok(devicesMigration003Sql.includes('device_name VARCHAR(255)'), 'Missing device_name in migration 003');
assert.ok(devicesMigration003Sql.includes('device_type VARCHAR(100)'), 'Missing device_type in migration 003');
assert.ok(devicesMigration003Sql.includes('plugin_id VARCHAR(128)'), 'Missing plugin_id in migration 003');
assert.ok(devicesMigration003Sql.includes('so_id UUID'), 'Missing so_id in migration 003');
assert.ok(devicesMigration003Sql.includes('so_number VARCHAR(100)'), 'Missing so_number in migration 003');
assert.ok(devicesMigration003Sql.includes('wa_id UUID'), 'Missing wa_id in migration 003');
assert.ok(devicesMigration003Sql.includes('wa_number VARCHAR(100)'), 'Missing wa_number in migration 003');
assert.ok(devicesMigration003Sql.includes('item_code VARCHAR(100)'), 'Missing item_code in migration 003');
assert.ok(devicesMigration003Sql.includes('devices.sync_device_serial_and_deveui()'), 'Missing sync_device_serial_and_deveui trigger in migration 003');
assert.ok(devicesMigration003Sql.includes('CREATE UNIQUE INDEX IF NOT EXISTS idx_devices_serial_number'), 'Missing idx_devices_serial_number in migration 003');
assert.ok(devicesMigration003Sql.includes('devices.testing_devices'), 'Missing devices.testing_devices view refresh in migration 003');
console.log('✓ Dedicated devices migration 003 validated');

// 13. Validate init-scripts and migrate.js registration for devices & decoder
assert.ok(initSql.includes('CREATE SCHEMA IF NOT EXISTS devices;'), 'Missing CREATE SCHEMA devices in 01-init-databases.sql');
assert.ok(initSql.includes('CREATE SCHEMA IF NOT EXISTS decoder;'), 'Missing CREATE SCHEMA decoder in 01-init-databases.sql');
assert.ok(initSql.includes('GRANT USAGE, CREATE ON SCHEMA devices TO itest_system_user;'), 'Missing itest_system_user grant on devices in 01-init-databases.sql');
assert.ok(initSql.includes('GRANT USAGE, CREATE ON SCHEMA decoder TO itest_plugins_user;'), 'Missing itest_plugins_user grant on decoder in 01-init-databases.sql');

const currentInitTablesSql = fs.readFileSync(path.join(__dirname, 'init-scripts/02-init-tables.sql'), 'utf8');
assert.ok(currentInitTablesSql.includes('\\i /opt/schemas/devices/schema.sql'), 'Missing devices schema in 02-init-tables.sql');
assert.ok(currentInitTablesSql.includes('\\i /opt/schemas/decoder/schema.sql'), 'Missing decoder schema in 02-init-tables.sql');

const migrateJs = fs.readFileSync(path.join(__dirname, 'scripts/migrate.js'), 'utf8');
assert.ok(migrateJs.includes("'devices':"), "Missing 'devices' source in migrate.js");
assert.ok(migrateJs.includes("'decoder':"), "Missing 'decoder' source in migrate.js");
console.log('✓ Configuration for devices and decoder in init-scripts and migrate.js validated');

console.log('--- ALL INTEGRITY TESTS PASSED ---');
