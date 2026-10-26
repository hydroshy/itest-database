/**
 * ITEST Database Migration & Management Engine (CLI)
 * PostgreSQL 17 Multi-Schema Manager
 * 
 * Usage:
 *   node scripts/migrate.js --source=all
 *   node scripts/migrate.js --source=system
 *   node scripts/migrate.js --source=plugins
 *   node scripts/migrate.js --source=ops-agent
 *   node scripts/migrate.js --status
 */

const fs = require('fs');
const path = require('path');
const { Client } = require('pg');
require('dotenv').config({ path: path.join(__dirname, '../.env') });

const DB_CONFIG = {
  host: process.env.POSTGRES_HOST || '127.0.0.1',
  port: parseInt(process.env.POSTGRES_PORT || '5432', 10),
  database: process.env.POSTGRES_DB || 'itest_platform',
  user: process.env.POSTGRES_USER || process.env.POSTGRES_SUPERUSER || 'postgres',
  password: process.env.POSTGRES_PASSWORD || process.env.POSTGRES_SUPERPASS || 'itest_secure_password_2026',
};

const SCHEMAS_DIR = path.join(__dirname, '../schemas');
const INIT_SCRIPTS_DIR = path.join(__dirname, '../init-scripts');

const SOURCES = {
  'init': {
    name: 'Core Init & Roles',
    dir: INIT_SCRIPTS_DIR,
    schema: 'public'
  },
  'system': {
    name: 'itest-system (Core Backbone)',
    dir: path.join(SCHEMAS_DIR, 'system/migrations'),
    schema: 'system_schema'
  },
  'plugins': {
    name: 'itest-plugins (IoT Plugins)',
    dir: path.join(SCHEMAS_DIR, 'plugins/migrations'),
    schema: 'plugins_schema'
  },
  'ops-agent': {
    name: 'itest-ops-agent (Telemetry & Monitoring)',
    dir: path.join(SCHEMAS_DIR, 'ops-agent'),
    schema: 'ops_schema'
  },
  'lorawan-chirpstack': {
    name: 'LoRaWAN ChirpStack Plugin',
    dir: path.join(SCHEMAS_DIR, 'lorawan-chirpstack/migrations'),
    schema: 'lorawan_chirpstack'
  },
  'memmap-manager': {
    name: 'MemMap Manager Plugin',
    dir: path.join(SCHEMAS_DIR, 'memmap-manager/migrations'),
    schema: 'memmap_manager'
  },
  'finalconfig-manager': {
    name: 'Final Config Manager Plugin',
    dir: path.join(SCHEMAS_DIR, 'finalconfig-manager/migrations'),
    schema: 'finalconfig_manager'
  },
  'traceability-manager': {
    name: 'Traceability Manager Plugin',
    dir: path.join(SCHEMAS_DIR, 'traceability-manager/migrations'),
    schema: 'traceability_manager'
  }
};

async function ensureMigrationTable(client) {
  await client.query(`
    CREATE TABLE IF NOT EXISTS public.__itest_migrations_history (
      id SERIAL PRIMARY KEY,
      source VARCHAR(64) NOT NULL,
      filename VARCHAR(255) NOT NULL,
      schema_name VARCHAR(64) NOT NULL,
      applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
      checksum VARCHAR(64),
      execution_time_ms INTEGER,
      status VARCHAR(20) DEFAULT 'SUCCESS',
      UNIQUE(source, filename)
    );
  `);
}

async function getAppliedMigrations(client, source) {
  const res = await client.query(
    'SELECT filename FROM public.__itest_migrations_history WHERE source = $1 AND status = $2',
    [source, 'SUCCESS']
  );
  return new Set(res.rows.map(r => r.filename));
}

async function recordMigration(client, source, filename, schemaName, timeMs) {
  await client.query(
    `INSERT INTO public.__itest_migrations_history (source, filename, schema_name, execution_time_ms, status)
     VALUES ($1, $2, $3, $4, 'SUCCESS')
     ON CONFLICT (source, filename) 
     DO UPDATE SET applied_at = CURRENT_TIMESTAMP, execution_time_ms = $4, status = 'SUCCESS'`,
    [source, filename, schemaName, timeMs]
  );
}

async function runSqlFile(client, filePath) {
  const sql = fs.readFileSync(filePath, 'utf8');
  await client.query(sql);
}

async function migrateSource(client, sourceKey) {
  const config = SOURCES[sourceKey];
  if (!config) {
    throw new Error(`Unknown source: ${sourceKey}`);
  }

  console.log(`\n======================================================`);
  console.log(`[MIGRATION] Running for [${config.name}] (Schema: ${config.schema})`);
  console.log(`======================================================`);

  if (!fs.existsSync(config.dir)) {
    console.log(`[WARN] Directory not found: ${config.dir}`);
    return;
  }

  const files = fs.readdirSync(config.dir)
    .filter(f => f.endsWith('.sql'))
    .sort();

  if (files.length === 0) {
    console.log(`[INFO] No SQL files found in ${config.dir}`);
    return;
  }

  const applied = await getAppliedMigrations(client, sourceKey);

  for (const file of files) {
    const fullPath = path.join(config.dir, file);
    if (applied.has(file)) {
      console.log(`  - [SKIPPED] ${file} (Already applied)`);
      continue;
    }

    console.log(`  > [APPLYING] ${file}...`);
    const start = Date.now();
    try {
      await client.query('BEGIN');
      await runSqlFile(client, fullPath);
      const duration = Date.now() - start;
      await recordMigration(client, sourceKey, file, config.schema, duration);
      await client.query('COMMIT');
      console.log(`  + [DONE] ${file} in ${duration}ms`);
    } catch (err) {
      await client.query('ROLLBACK');
      console.error(`  x [FAILED] ${file}: ${err.message}`);
      throw err;
    }
  }
}

async function showStatus(client) {
  console.log(`\n======================================================`);
  console.log(`ITEST PLATFORM DATABASE MIGRATION STATUS`);
  console.log(`Database: ${DB_CONFIG.database} @ ${DB_CONFIG.host}:${DB_CONFIG.port}`);
  console.log(`======================================================`);

  for (const [key, config] of Object.entries(SOURCES)) {
    console.log(`\n-- Source: ${config.name} (${key}) --`);
    if (!fs.existsSync(config.dir)) {
      console.log(`   (directory missing: ${config.dir})`);
      continue;
    }
    const diskFiles = fs.readdirSync(config.dir).filter(f => f.endsWith('.sql')).sort();
    const applied = await getAppliedMigrations(client, key);

    for (const f of diskFiles) {
      const isApplied = applied.has(f);
      console.log(`   [${isApplied ? 'APPLIED' : 'PENDING'}] ${f}`);
    }
  }

  // Schema Table Counts
  console.log(`\n-- Schemas & Tables Overview --`);
  const schemas = ['system_schema', 'plugins_schema', 'ops_schema', 'lorawan_chirpstack', 'memmap_manager'];
  for (const s of schemas) {
    const res = await client.query(`
      SELECT table_name 
      FROM information_schema.tables 
      WHERE table_schema = $1
      ORDER BY table_name;
    `, [s]);
    console.log(`   Schema [${s}]: ${res.rows.length} table(s)`);
    if (res.rows.length > 0) {
      console.log(`     -> ${res.rows.map(r => r.table_name).join(', ')}`);
    }
  }
}

async function main() {
  const args = process.argv.slice(2);
  const sourceArg = args.find(a => a.startsWith('--source='));
  const isStatus = args.includes('--status');
  const targetSource = sourceArg ? sourceArg.split('=')[1] : null;

  const client = new Client(DB_CONFIG);

  try {
    await client.connect();
    console.log(`Connected to PostgreSQL server at ${DB_CONFIG.host}:${DB_CONFIG.port}/${DB_CONFIG.database}`);

    await ensureMigrationTable(client);

    if (isStatus) {
      await showStatus(client);
      return;
    }

    if (!targetSource || targetSource === 'all') {
      // Run init first if pending, then schemas
      for (const key of ['init', 'system', 'plugins', 'lorawan-chirpstack', 'memmap-manager', 'ops-agent']) {
        await migrateSource(client, key);
      }
    } else if (SOURCES[targetSource]) {
      await migrateSource(client, targetSource);
    } else {
      console.error(`Invalid --source=${targetSource}. Available: ${Object.keys(SOURCES).join(', ')}, all`);
      process.exit(1);
    }

    console.log(`\n[SUCCESS] Migration finished cleanly.`);
  } catch (err) {
    console.error(`\n[ERROR] Migration process aborted:`, err.message);
    process.exit(1);
  } finally {
    await client.end();
  }
}

main();
