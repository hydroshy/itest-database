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
console.log('✓ scripts/migrate.js contains lorawan-chirpstack source');

console.log('--- ALL INTEGRITY TESTS PASSED ---');
