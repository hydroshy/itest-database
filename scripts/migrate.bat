@echo off
chcp 65001 >nul
REM ==============================================================================
REM ITEST PLATFORM - DATABASE MIGRATION SCRIPT FOR WINDOWS
REM Usage:
REM   migrate.bat                (Migrates all schemas)
REM   migrate.bat system         (Migrates itest-system schema only)
REM   migrate.bat plugins        (Migrates itest-plugins schema only)
REM   migrate.bat ops-agent      (Migrates itest-ops-agent schema only)
REM   migrate.bat status         (Displays migration and schema status)
REM ==============================================================================

setlocal enabledelayedexpansion
cd /d "%~dp0.."

if not exist ".env" (
    if exist ".env.example" (
        echo [INFO] Creating .env from .env.example...
        copy .env.example .env >nul
    )
)

if not exist "node_modules\pg" (
    echo [INFO] Installing required Node.js dependencies (pg, dotenv)...
    cmd /c "npm install pg dotenv --save"
)

if "%1"=="" (
    node scripts/migrate.js --source=all
) else if "%1"=="status" (
    node scripts/migrate.js --status
) else (
    node scripts/migrate.js --source=%1
)

endlocal
