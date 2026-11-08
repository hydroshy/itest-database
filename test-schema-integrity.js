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
  'schemas/system/migrations/006_add_gateway_testing_and_device_plugin_menus.sql',
  'schemas/system/migrations/007_create_simulation_profiles_and_runs.sql',
  'schemas/system/migrations/008_extend_simulation_profiles_for_block_flow.sql',
  'schemas/system/migrations/009_create_device_test_sessions_and_menu.sql',
  'schemas/system/migrations/010_create_device_test_registrations_and_views.sql',
  'schemas/system/migrations/011_create_list_device_testing_menu_and_indexes.sql',
  'schemas/system/migrations/012_create_device_test_batches_and_menus.sql',
  'schemas/system/migrations/013_add_long_fw_to_device_test_registrations.sql',
  'schemas/system/migrations/014_enhance_device_packets_and_create_payload_live_view.sql',
  'schemas/lorawan-chirpstack/migrations/003_create_gateway_test_sessions.sql',
  'schemas/plugins/migrations/001_create_decoder_scripts_and_views.sql',
  'schemas/decoder/schema.sql',
  'schemas/decoder/migrations/001_create_decoder_schema_and_tables.sql',
  'schemas/decoder/migrations/002_add_name_column_to_decoder_scripts.sql',
  'schemas/decoder/migrations/003_add_item_code_and_fw_code_to_decoder_scripts.sql',
  'schemas/devices/schema.sql',
  'schemas/devices/migrations/001_create_devices_schema_and_tables.sql',
  'schemas/devices/migrations/002_add_device_id_and_gateway_name_columns.sql',
  'schemas/devices/migrations/003_add_device_serial_number_and_traceability_columns.sql',
  'schemas/devices/migrations/004_update_device_plugin_id_default_to_device.sql',
  'schemas/devices/migrations/005_extend_gateway_test_sessions_metadata.sql',
  'schemas/devices/migrations/006_add_packet_spreading_factor.sql',
  'schemas/lorawan-chirpstack/migrations/004_extend_gateway_test_sessions_metadata.sql',
  'schemas/lorawan-chirpstack/migrations/005_add_app_and_device_profile_to_network_servers.sql',
  'schemas/system/migrations/021_create_so_test_batches_and_menus.sql',
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

// 14. Validate System Migration 006 (Gateway Testing & Device Plugin Menus)
const systemMigration006Sql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/006_add_gateway_testing_and_device_plugin_menus.sql'), 'utf8');
assert.ok(systemMigration006Sql.includes("'testing:gateway'"), "Missing 'testing:gateway' in system migration 006");
assert.ok(systemMigration006Sql.includes("'device:devices'"), "Missing 'device:devices' in system migration 006");
assert.ok(systemMigration006Sql.includes("'Gateway Testing'"), "Missing 'Gateway Testing' title in system migration 006");
assert.ok(systemMigration006Sql.includes("'/plugins/testing?tab=gateway'"), "Missing Gateway route in system migration 006");
assert.ok(systemMigration006Sql.includes("'/plugins/device?tab=devices'"), "Missing Device route in system migration 006");
assert.ok(systemMigration006Sql.includes("'menu:testing-gateway:view'"), "Missing menu:testing-gateway:view permission");
assert.ok(systemMigration006Sql.includes("'menu:device-devices:view'"), "Missing menu:device-devices:view permission");
assert.ok(systemMigration006Sql.includes("ALTER TABLE system_schema.\"devices\" ALTER COLUMN \"plugin_id\" SET DEFAULT 'device'"), "Missing default 'device' in system migration 006");
console.log('✓ System migration 006 for Gateway Testing and Device menus validated');

// 15. Validate Devices Migration 004 (Device Plugin ID default update)
const devicesMigration004Sql = fs.readFileSync(path.join(__dirname, 'schemas/devices/migrations/004_update_device_plugin_id_default_to_device.sql'), 'utf8');
assert.ok(devicesMigration004Sql.includes("ALTER TABLE devices.devices ALTER COLUMN plugin_id SET DEFAULT 'device'"), "Missing ALTER COLUMN plugin_id SET DEFAULT 'device' in devices migration 004");
assert.ok(devicesMigration004Sql.includes("NEW.plugin_id = 'device'"), "Missing NEW.plugin_id = 'device' trigger update in devices migration 004");
console.log('✓ Devices migration 004 validated');

// 16. Validate Schema files for Gateway Testing & Device Separation
const systemSchemaSql = fs.readFileSync(path.join(__dirname, 'schemas/system/schema.sql'), 'utf8');
const lorawanSchemaSql = fs.readFileSync(path.join(__dirname, 'schemas/lorawan-chirpstack/schema.sql'), 'utf8');
assert.ok(systemSchemaSql.includes("'testing:gateway'"), "Missing 'testing:gateway' in system/schema.sql");
assert.ok(systemSchemaSql.includes("'device:devices'"), "Missing 'device:devices' in system/schema.sql");
assert.ok(systemSchemaSql.includes('"plugin_id" VARCHAR(128) NOT NULL DEFAULT \'device\''), "Missing default 'device' for plugin_id in system/schema.sql");

assert.ok(devicesSchemaSql.includes("plugin_id VARCHAR(128) DEFAULT 'device'"), "Missing default 'device' for plugin_id in devices/schema.sql");
assert.ok(devicesSchemaSql.includes("NEW.plugin_id = 'device'"), "Missing NEW.plugin_id = 'device' in devices/schema.sql trigger");
console.log('✓ Schema files consistency for Gateway Testing and Device Separation validated');

// 17. Validate LoRaWAN ChirpStack Migration 004 and Schema Entrypoint
const lorawanMigration004Sql = fs.readFileSync(path.join(__dirname, 'schemas/lorawan-chirpstack/migrations/004_extend_gateway_test_sessions_metadata.sql'), 'utf8');
assert.ok(lorawanMigration004Sql.includes('so_number VARCHAR(100)'), 'Missing so_number in lorawan migration 004');
assert.ok(lorawanMigration004Sql.includes('wa_number VARCHAR(100)'), 'Missing wa_number in lorawan migration 004');
assert.ok(lorawanMigration004Sql.includes('serial_number VARCHAR(100)'), 'Missing serial_number in lorawan migration 004');
assert.ok(lorawanMigration004Sql.includes('gateway_ip VARCHAR(45)'), 'Missing gateway_ip in lorawan migration 004');
assert.ok(lorawanMigration004Sql.includes('internet_test_type VARCHAR(20)'), 'Missing internet_test_type in lorawan migration 004');
assert.ok(lorawanMigration004Sql.includes('region_test VARCHAR(50)'), 'Missing region_test in lorawan migration 004');
assert.ok(lorawanMigration004Sql.includes('network_server_id UUID'), 'Missing network_server_id in lorawan migration 004');
assert.ok(lorawanMigration004Sql.includes('config_snapshot JSONB'), 'Missing config_snapshot in lorawan migration 004');
assert.ok(lorawanMigration004Sql.includes('forwarder_config JSONB'), 'Missing forwarder_config in lorawan migration 004');
assert.ok(lorawanMigration004Sql.includes('v_gateway_test_sessions_detail'), 'Missing v_gateway_test_sessions_detail view in lorawan migration 004');
assert.ok(lorawanMigration004Sql.includes('GRANT SELECT ON lorawan_chirpstack.v_gateway_test_sessions_detail TO itest_system_user'), 'Missing GRANT for v_gateway_test_sessions_detail');
assert.ok(lorawanSchemaSql.includes('004_extend_gateway_test_sessions_metadata.sql'), 'Missing 004 migration in lorawan-chirpstack/schema.sql');
console.log('✓ LoRaWAN ChirpStack migration 004 and detail view validated');

// 18. Validate Devices Migration 005 and Devices Schema Gateway Metadata
const devicesMigration005Sql = fs.readFileSync(path.join(__dirname, 'schemas/devices/migrations/005_extend_gateway_test_sessions_metadata.sql'), 'utf8');
assert.ok(devicesMigration005Sql.includes('so_number VARCHAR(100)'), 'Missing so_number in devices migration 005');
assert.ok(devicesMigration005Sql.includes('wa_number VARCHAR(100)'), 'Missing wa_number in devices migration 005');
assert.ok(devicesMigration005Sql.includes('serial_number VARCHAR(100)'), 'Missing serial_number in devices migration 005');
assert.ok(devicesMigration005Sql.includes('gateway_ip VARCHAR(45)'), 'Missing gateway_ip in devices migration 005');
assert.ok(devicesMigration005Sql.includes('internet_test_type VARCHAR(20)'), 'Missing internet_test_type in devices migration 005');
assert.ok(devicesMigration005Sql.includes('region_test VARCHAR(50)'), 'Missing region_test in devices migration 005');
assert.ok(devicesMigration005Sql.includes('network_server_id UUID'), 'Missing network_server_id in devices migration 005');
assert.ok(devicesMigration005Sql.includes('config_snapshot JSONB'), 'Missing config_snapshot in devices migration 005');
assert.ok(devicesMigration005Sql.includes('forwarder_config JSONB'), 'Missing forwarder_config in devices migration 005');
assert.ok(devicesMigration005Sql.includes('idx_devices_gw_sessions_serial_number'), 'Missing serial_number index in devices migration 005');
assert.ok(devicesMigration005Sql.includes('idx_devices_gw_sessions_gateway_ip'), 'Missing gateway_ip index in devices migration 005');
assert.ok(devicesMigration005Sql.includes('idx_devices_gw_sessions_network_server_id'), 'Missing network_server_id index in devices migration 005');
assert.ok(devicesMigration005Sql.includes('devices.sync_gateway_test_sessions_columns()'), 'Missing sync_gateway_test_sessions_columns in devices migration 005');

assert.ok(devicesSchemaSql.includes('so_number VARCHAR(100)'), 'Missing so_number in devices/schema.sql gateway_test_sessions');
assert.ok(devicesSchemaSql.includes('serial_number VARCHAR(100)'), 'Missing serial_number in devices/schema.sql gateway_test_sessions');
assert.ok(devicesSchemaSql.includes('gateway_ip VARCHAR(45)'), 'Missing gateway_ip in devices/schema.sql gateway_test_sessions');
assert.ok(devicesSchemaSql.includes('idx_devices_gw_sessions_serial_number'), 'Missing idx_devices_gw_sessions_serial_number in devices/schema.sql');
console.log('✓ Devices migration 005 and devices/schema.sql gateway metadata validated');

// 19. Validate System Migration 007 and system/schema.sql for Simulation Profiles and Runs
const systemMigration007Sql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/007_create_simulation_profiles_and_runs.sql'), 'utf8');
assert.ok(systemMigration007Sql.includes('CREATE TABLE IF NOT EXISTS system_schema."simulation_profiles"'), 'Missing simulation_profiles table in system migration 007');
assert.ok(systemMigration007Sql.includes('"simu_id" VARCHAR(100) NOT NULL UNIQUE'), 'Missing simu_id in simulation_profiles');
assert.ok(systemMigration007Sql.includes('"item_code" VARCHAR(100) NOT NULL'), 'Missing item_code in simulation_profiles');
assert.ok(systemMigration007Sql.includes('"long_fw" VARCHAR(255) NOT NULL'), 'Missing long_fw in simulation_profiles');
assert.ok(systemMigration007Sql.includes('"f_port" INTEGER NOT NULL DEFAULT 10'), 'Missing f_port in simulation_profiles');
assert.ok(systemMigration007Sql.includes('"preset_id" VARCHAR(50) NOT NULL DEFAULT \'env\''), 'Missing preset_id in simulation_profiles');
assert.ok(systemMigration007Sql.includes('"flow_duration_minutes" INTEGER NOT NULL DEFAULT 30'), 'Missing flow_duration_minutes in simulation_profiles');
assert.ok(systemMigration007Sql.includes('"timed_actions" JSONB NOT NULL DEFAULT \'[]\'::jsonb'), 'Missing timed_actions in simulation_profiles');

assert.ok(systemMigration007Sql.includes('CREATE TABLE IF NOT EXISTS system_schema."simulation_runs"'), 'Missing simulation_runs table in system migration 007');
assert.ok(systemMigration007Sql.includes('"simu_id" VARCHAR(100) NOT NULL REFERENCES system_schema."simulation_profiles"("simu_id")'), 'Missing simu_id FK in simulation_runs');
assert.ok(systemMigration007Sql.includes('"duration_seconds" INTEGER NOT NULL DEFAULT 1800'), 'Missing duration_seconds in simulation_runs');
assert.ok(systemMigration007Sql.includes('"actuator_events" JSONB NOT NULL DEFAULT \'[]\'::jsonb'), 'Missing actuator_events in simulation_runs');
assert.ok(systemMigration007Sql.includes('"logs" JSONB NOT NULL DEFAULT \'[]\'::jsonb'), 'Missing logs in simulation_runs');

// Check system/schema.sql has simulation tables
const updatedSystemSchemaSql = fs.readFileSync(path.join(__dirname, 'schemas/system/schema.sql'), 'utf8');
assert.ok(updatedSystemSchemaSql.includes('CREATE TABLE IF NOT EXISTS system_schema."simulation_profiles"'), 'Missing simulation_profiles in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('CREATE TABLE IF NOT EXISTS system_schema."simulation_runs"'), 'Missing simulation_runs in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('"timed_actions" JSONB NOT NULL DEFAULT \'[]\'::jsonb'), 'Missing timed_actions in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('"actuator_events" JSONB NOT NULL DEFAULT \'[]\'::jsonb'), 'Missing actuator_events in system/schema.sql');
console.log('✓ System migration 007 and system/schema.sql simulation tables validated');

// 20. Validate System Migration 008 and system/schema.sql for Simulation Block Flow
const systemMigration008Sql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/008_extend_simulation_profiles_for_block_flow.sql'), 'utf8');
assert.ok(systemMigration008Sql.includes('ADD COLUMN IF NOT EXISTS "sensor_connectivity" VARCHAR(100) NOT NULL DEFAULT \'LoRaWAN\''), 'Missing sensor_connectivity column');
assert.ok(systemMigration008Sql.includes('ADD COLUMN IF NOT EXISTS "sku" VARCHAR(100)'), 'Missing sku column');
assert.ok(systemMigration008Sql.includes('ADD COLUMN IF NOT EXISTS "flow_blocks" JSONB NOT NULL DEFAULT \'[]\'::jsonb'), 'Missing flow_blocks column');
assert.ok(systemMigration008Sql.includes('idx_simu_profiles_sku_long_fw'), 'Missing idx_simu_profiles_sku_long_fw index');
assert.ok(systemMigration008Sql.includes('v_simulation_devices'), 'Missing v_simulation_devices view');
assert.ok(systemMigration008Sql.includes("WHERE d.\"status\" IN ('simulation', 'template')"), 'Missing status filter in view');

assert.ok(updatedSystemSchemaSql.includes('"sensor_connectivity" VARCHAR(100) NOT NULL DEFAULT \'LoRaWAN\''), 'Missing sensor_connectivity in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('"sku" VARCHAR(100)'), 'Missing sku in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('"flow_blocks" JSONB NOT NULL DEFAULT \'[]\'::jsonb'), 'Missing flow_blocks in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('idx_simu_profiles_sku_long_fw'), 'Missing idx_simu_profiles_sku_long_fw in system/schema.sql');
console.log('✓ System migration 008 and system/schema.sql block flow fields validated');

// 21. Validate System Migration 009 and system/schema.sql for Create Device Testing
const systemMigration009Sql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/009_create_device_test_sessions_and_menu.sql'), 'utf8');
assert.ok(systemMigration009Sql.includes('CREATE TABLE IF NOT EXISTS system_schema."device_test_sessions"'), 'Missing device_test_sessions table in migration 009');
assert.ok(systemMigration009Sql.includes('"session_code" VARCHAR(100) NOT NULL UNIQUE'), 'Missing session_code in migration 009');
assert.ok(systemMigration009Sql.includes('testing:create-device-testing'), 'Missing menu item testing:create-device-testing in migration 009');
assert.ok(systemMigration009Sql.includes('menu:testing-create-device:view'), 'Missing permission in migration 009');
assert.ok(systemMigration009Sql.includes('v_device_test_sessions'), 'Missing v_device_test_sessions view in migration 009');

assert.ok(updatedSystemSchemaSql.includes('CREATE TABLE IF NOT EXISTS system_schema."device_test_sessions"'), 'Missing device_test_sessions in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('"session_code" VARCHAR(100) NOT NULL UNIQUE'), 'Missing session_code in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('v_device_test_sessions'), 'Missing v_device_test_sessions view in system/schema.sql');
console.log('✓ System migration 009 and system/schema.sql device test sessions validated');

// 22. Validate System Migration 010 and system/schema.sql for 3-Step Device Test Registrations
const systemMigration010Sql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/010_create_device_test_registrations_and_views.sql'), 'utf8');
assert.ok(systemMigration010Sql.includes('CREATE TABLE IF NOT EXISTS system_schema."device_test_registrations"'), 'Missing device_test_registrations table in migration 010');
assert.ok(systemMigration010Sql.includes('"registration_code" VARCHAR(100) NOT NULL UNIQUE'), 'Missing registration_code in migration 010');
assert.ok(systemMigration010Sql.includes('"connectivity" VARCHAR(50) NOT NULL DEFAULT \'LoRaWAN\''), 'Missing connectivity in migration 010');
assert.ok(systemMigration010Sql.includes('"fw_code" VARCHAR(50)'), 'Missing fw_code in migration 010');
assert.ok(systemMigration010Sql.includes('"fw_version" VARCHAR(50)'), 'Missing fw_version in migration 010');
assert.ok(systemMigration010Sql.includes('"dev_eui" VARCHAR(64)'), 'Missing dev_eui in migration 010');
assert.ok(systemMigration010Sql.includes('"app_eui" VARCHAR(64)'), 'Missing app_eui in migration 010');
assert.ok(systemMigration010Sql.includes('"app_key" VARCHAR(64)'), 'Missing app_key in migration 010');
assert.ok(systemMigration010Sql.includes('"serial_number" VARCHAR(100)'), 'Missing serial_number in migration 010');
assert.ok(systemMigration010Sql.includes('v_device_test_registrations_detail'), 'Missing v_device_test_registrations_detail view in migration 010');
assert.ok(systemMigration010Sql.includes('v_testing_active_traceability'), 'Missing v_testing_active_traceability view in migration 010');

assert.ok(updatedSystemSchemaSql.includes('CREATE TABLE IF NOT EXISTS system_schema."device_test_registrations"'), 'Missing device_test_registrations in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('"registration_code" VARCHAR(100) NOT NULL UNIQUE'), 'Missing registration_code in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('v_device_test_registrations_detail'), 'Missing v_device_test_registrations_detail view in system/schema.sql');
console.log('✓ System migration 010 and system/schema.sql 3-step registration flow validated');

// 23. Validate LoRaWAN ChirpStack Migration 005 for Application ID & Device Profile ID
const lorawanMigration005Sql = fs.readFileSync(path.join(__dirname, 'schemas/lorawan-chirpstack/migrations/005_add_app_and_device_profile_to_network_servers.sql'), 'utf8');
assert.ok(lorawanMigration005Sql.includes('ADD COLUMN IF NOT EXISTS "application_id" VARCHAR(100)'), 'Missing application_id in lorawan migration 005');
assert.ok(lorawanMigration005Sql.includes('ADD COLUMN IF NOT EXISTS "device_profile_id" VARCHAR(100)'), 'Missing device_profile_id in lorawan migration 005');
assert.ok(lorawanMigration005Sql.includes('idx_lorawan_cs_network_servers_app_id'), 'Missing app_id index in lorawan migration 005');
assert.ok(lorawanMigration005Sql.includes('idx_lorawan_cs_network_servers_dev_profile_id'), 'Missing dev_profile_id index in lorawan migration 005');
assert.ok(lorawanSchemaSql.includes('005_add_app_and_device_profile_to_network_servers.sql'), 'Missing migration 005 in lorawan-chirpstack/schema.sql');
console.log('✓ LoRaWAN ChirpStack migration 005 for Application ID and Device Profile ID validated');

// 24. Validate System Migration 011 for List Device Testing Menu, Indexes and View
const systemMigration011Sql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/011_create_list_device_testing_menu_and_indexes.sql'), 'utf8');
assert.ok(systemMigration011Sql.includes('testing:list-device-testing'), 'Missing testing:list-device-testing menu item in migration 011');
assert.ok(systemMigration011Sql.includes('idx_dtest_reg_user_app'), 'Missing idx_dtest_reg_user_app in migration 011');
assert.ok(systemMigration011Sql.includes('v_list_device_testing'), 'Missing v_list_device_testing view in migration 011');
assert.ok(updatedSystemSchemaSql.includes('v_list_device_testing'), 'Missing v_list_device_testing in system/schema.sql');
console.log('✓ System migration 011 and system/schema.sql list device testing validated');

// 25. Validate System Migration 012 for Device Test Batches and Items (Create Test Batch & Device Test Batch)
const systemMigration012Sql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/012_create_device_test_batches_and_menus.sql'), 'utf8');
assert.ok(systemMigration012Sql.includes('CREATE TABLE IF NOT EXISTS system_schema."device_test_batches"'), 'Missing device_test_batches table in migration 012');
assert.ok(systemMigration012Sql.includes('CREATE TABLE IF NOT EXISTS system_schema."device_test_batch_items"'), 'Missing device_test_batch_items table in migration 012');
assert.ok(systemMigration012Sql.includes('reference_serial_number'), 'Missing reference_serial_number column in migration 012');
assert.ok(systemMigration012Sql.includes('testing:create-test-batch'), 'Missing testing:create-test-batch menu item in migration 012');
assert.ok(systemMigration012Sql.includes('testing:test-batch'), 'Missing testing:test-batch menu item in migration 012');
assert.ok(systemMigration012Sql.includes('v_device_test_batches'), 'Missing v_device_test_batches view in migration 012');
assert.ok(systemMigration012Sql.includes('v_device_test_batch_items_detail'), 'Missing v_device_test_batch_items_detail view in migration 012');
assert.ok(updatedSystemSchemaSql.includes('device_test_batches'), 'Missing device_test_batches in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('v_device_test_batches'), 'Missing v_device_test_batches in system/schema.sql');
console.log('✓ System migration 012 and system/schema.sql test batches validated');

// 26. Validate System Migration 013 for long_fw column in device_test_registrations and view
const systemMigration013Sql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/013_add_long_fw_to_device_test_registrations.sql'), 'utf8');
assert.ok(systemMigration013Sql.includes('ALTER TABLE system_schema."device_test_registrations"'), 'Missing ALTER TABLE in migration 013');
assert.ok(systemMigration013Sql.includes('"long_fw" VARCHAR(255)'), 'Missing long_fw column in migration 013');
assert.ok(systemMigration013Sql.includes('UPDATE system_schema."device_test_registrations"'), 'Missing backfill UPDATE in migration 013');
assert.ok(systemMigration013Sql.includes('COALESCE(r."long_fw", r."fw_version") AS "long_fw"'), 'Missing long_fw in v_list_device_testing view in migration 013');
assert.ok(updatedSystemSchemaSql.includes('"long_fw" VARCHAR(255)'), 'Missing long_fw in system/schema.sql table');
assert.ok(updatedSystemSchemaSql.includes('COALESCE(r."long_fw", r."fw_version") AS "long_fw"'), 'Missing long_fw in system/schema.sql view');
console.log('✓ System migration 013 and system/schema.sql long_fw support validated');

// 27. Validate System Migration 014 for device_packets enhancement and v_device_payload_live
const systemMigration014Sql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/014_enhance_device_packets_and_create_payload_live_view.sql'), 'utf8');
assert.ok(systemMigration014Sql.includes('"rssi" DOUBLE PRECISION'), 'Missing rssi column in migration 014');
assert.ok(systemMigration014Sql.includes('"snr" DOUBLE PRECISION'), 'Missing snr column in migration 014');
assert.ok(systemMigration014Sql.includes('"frequency" DOUBLE PRECISION'), 'Missing frequency column in migration 014');
assert.ok(systemMigration014Sql.includes('v_device_payload_live'), 'Missing v_device_payload_live view in migration 014');
assert.ok(systemMigration014Sql.includes('testing:device-payload'), 'Missing testing:device-payload menu item in migration 014');
assert.ok(updatedSystemSchemaSql.includes('v_device_payload_live'), 'Missing v_device_payload_live in system/schema.sql');
assert.ok(updatedSystemSchemaSql.includes('testing:device-payload'), 'Missing testing:device-payload in system/schema.sql');
console.log('✓ System migration 014 and system/schema.sql device_packets & payload live view validated');

const packetRfMigration = fs.readFileSync(path.join(__dirname, 'schemas/devices/migrations/006_add_packet_spreading_factor.sql'), 'utf8');
assert.ok(packetRfMigration.includes('ALTER TABLE devices.device_packets'), 'RF migration must target backend physical table');
assert.ok(packetRfMigration.includes('ADD COLUMN IF NOT EXISTS sf INTEGER'), 'Missing numeric spreading factor');
assert.ok(!/ALTER COLUMN\s+\w+\s+TYPE/i.test(packetRfMigration), 'RF migration must preserve types used by compatibility views');

const autoCheckProfileSql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/015_create_device_autocheck_profiles.sql'), 'utf8');
for (const sql of [autoCheckProfileSql, updatedSystemSchemaSql]) {
  assert.ok(sql.includes('CREATE TABLE IF NOT EXISTS system_schema.device_autocheck_profiles'), 'Missing persistent AutoCheck profiles');
  assert.ok(sql.includes("autocheck_id VARCHAR(40) NOT NULL UNIQUE DEFAULT ('AC-'"), 'AutoCheck ID must be generated by database');
  assert.ok(sql.includes("CHECK (jsonb_typeof(criteria) = 'object')"), 'Criteria must be a JSON object');
  assert.ok(sql.includes('reference_item_code IS NULL AND reference_fw_version IS NULL'), 'Reference product identity must be paired');
}

// Simulation flows retain seconds and protect test-batch references.
const flowLinksMigration = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/019_protect_simulation_flow_batch_links.sql'), 'utf8');
for (const sql of [flowLinksMigration, updatedSystemSchemaSql]) {
  assert.ok(sql.includes('fk_device_test_batches_simulation_flow'), 'Missing flow/batch foreign key');
  assert.ok(sql.includes('ON DELETE RESTRICT NOT VALID'), 'Protect deletes without discarding legacy orphans');
  assert.ok(sql.includes('idx_dtest_batches_simu_id'), 'Missing flow/batch lookup index');
  assert.ok(sql.includes('WHERE canonical.simu_id = b.simu_id'), 'UUID normalization must prefer canonical IDs');
}
assert.ok(flowLinksMigration.includes('TYPE NUMERIC USING flow_duration_minutes::numeric'), 'Migration must preserve fractional minutes');
assert.ok(updatedSystemSchemaSql.includes('"flow_duration_minutes" NUMERIC NOT NULL'), 'Fresh schema must preserve fractional minutes');
assert.ok(!flowLinksMigration.includes('DROP VIEW IF EXISTS system_schema.v_simulation_flows CASCADE'), 'Do not drop unrelated dependent views');
console.log('✓ Flow duration precision and batch link protection validated');

// Simulation devices view must exclude templates and mock data.
const simDevicesMigration = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/020_filter_simulation_devices_exclude_templates.sql'), 'utf8');
const extractSimView = (str) => {
  const match = str.match(/CREATE OR REPLACE VIEW system_schema\.v_simulation_devices[\s\S]*?(?:;|\$\$)/);
  return match ? match[0] : str;
};
for (const sql of [simDevicesMigration, updatedSystemSchemaSql]) {
  assert.ok(sql.includes('v_simulation_devices'), 'Missing v_simulation_devices view definition');
  assert.ok(sql.includes("status'' = ''simulation''") || sql.includes("status\" = 'simulation'") || sql.includes("status\" = ''simulation''"), 'v_simulation_devices must filter status = simulation only');
  const viewSql = extractSimView(sql);
  assert.ok(!viewSql.includes("''template''") && !viewSql.includes("'template'"), 'v_simulation_devices must never include template status');
}
console.log('✓ Simulation devices view cleanly excludes templates and mock data');

// 29. Validate System Migration 021 for so_test_batches and menus
const systemMigration021Sql = fs.readFileSync(path.join(__dirname, 'schemas/system/migrations/021_create_so_test_batches_and_menus.sql'), 'utf8');
const freshSystemSchemaSql = fs.readFileSync(path.join(__dirname, 'schemas/system/schema.sql'), 'utf8');

for (const sql of [systemMigration021Sql, freshSystemSchemaSql]) {
  assert.ok(sql.includes('CREATE TABLE IF NOT EXISTS system_schema."so_test_batches"'), 'Missing so_test_batches table');
  assert.ok(sql.includes('"so_id" UUID NOT NULL REFERENCES traceability_manager."traceability_so"'), 'Missing so_id foreign key');
  assert.ok(sql.includes('"batch_id" UUID NOT NULL REFERENCES system_schema."device_test_batches"'), 'Missing batch_id foreign key');
  assert.ok(sql.includes('uq_so_test_batches_so_batch UNIQUE ("so_id", "batch_id")'), 'Missing unique constraint on so_id and batch_id');
  assert.ok(sql.includes('v_so_test_batches_detail'), 'Missing v_so_test_batches_detail view');
  assert.ok(sql.includes('v_so_with_test_batches'), 'Missing v_so_with_test_batches view');
  assert.ok(sql.includes('v_available_test_batches'), 'Missing v_available_test_batches view');
  assert.ok(sql.includes('GRANT ALL PRIVILEGES ON TABLE system_schema."so_test_batches" TO itest_system_user'), 'Missing itest_system_user grant on so_test_batches');
  assert.ok(sql.includes('GRANT ALL PRIVILEGES ON TABLE system_schema."so_test_batches" TO itest_plugins_user'), 'Missing itest_plugins_user grant on so_test_batches');
}

assert.ok(systemMigration021Sql.includes('so-test-batch:so-test-batch'), 'Missing menu item so-test-batch:so-test-batch in migration 021');
assert.ok(systemMigration021Sql.includes('/plugins/so-test-batch'), 'Missing route /plugins/so-test-batch in migration 021');
assert.ok(systemMigration021Sql.includes('so-test-batch:link:create'), 'Missing so-test-batch:link:create permission in migration 021');
assert.ok(systemMigration021Sql.includes('so-test-batch:link:delete'), 'Missing so-test-batch:link:delete permission in migration 021');
console.log('✓ System migration 021 and schema.sql so_test_batches validated');

console.log('--- ALL INTEGRITY TESTS PASSED ---');
