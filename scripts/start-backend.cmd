@echo off
REM ==========================================================================
REM  CodeYoung - start the Node.js REST API (SQLite backed)
REM  Run from the repository root:   scripts\start-backend.cmd
REM  Requires: Node.js 22.5+ (uses the built-in node:sqlite module)
REM ==========================================================================
setlocal
cd /d "%~dp0..\backend"

if not exist "node_modules" (
  echo [backend] installing dependencies...
  call npm install
  if errorlevel 1 (
    echo [backend] npm install failed.
    exit /b 1
  )
)

echo [backend] starting on http://127.0.0.1:3000
node server.js
endlocal
