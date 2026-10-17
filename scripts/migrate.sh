#!/usr/bin/env bash
# ==============================================================================
# ITEST PLATFORM - DATABASE MIGRATION SCRIPT FOR LINUX / MACOS / DOCKER
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

if [ ! -f ".env" ] && [ -f ".env.example" ]; then
    echo "[INFO] Creating .env from .env.example..."
    cp .env.example .env
fi

if [ ! -d "node_modules/pg" ]; then
    echo "[INFO] Installing required dependencies..."
    npm install pg dotenv --save
fi

TARGET="${1:-all}"

if [ "$TARGET" = "status" ]; then
    node scripts/migrate.js --status
else
    node scripts/migrate.js "--source=$TARGET"
fi
