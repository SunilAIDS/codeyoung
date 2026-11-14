<#
.SYNOPSIS
  Starts the whole CodeYoung stack: Node API (3000) + Python mentor (5001).

.DESCRIPTION
  Opens each service in its own window so their logs stay separate.
  Close those windows to stop the services.

  Usage, from the repository root:

      powershell -ExecutionPolicy Bypass -File scripts\start-all.ps1

  Then run the Flutter app:

      cd CodeYoung
      flutter run            # desktop / web / device
      flutter run -d chrome  # web in Chrome

.NOTES
  On the Android emulator the app talks to the host via http://10.0.2.2:3000,
  which the app configures automatically. On desktop/iOS/web it uses
  http://127.0.0.1:3000.
#>

$root = Split-Path -Parent $PSScriptRoot
$backend = Join-Path $root 'backend'
$chatbot = Join-Path $root 'chatbot'

function Start-ServiceWindow {
    param([string]$Title, [string]$WorkingDir, [string]$Command)

    $arg = "-NoExit -NoLogo -Command `"Set-Location -LiteralPath '$WorkingDir'; $Command`""
    Start-Process -FilePath 'powershell.exe' -ArgumentList $arg -WindowStyle Normal
    Write-Host "  started: $Title" -ForegroundColor Green
}

Write-Host ''
Write-Host 'Starting CodeYoung services...' -ForegroundColor Cyan

# Backend ---------------------------------------------------------------
if (-not (Test-Path (Join-Path $backend 'node_modules'))) {
    Write-Host '  installing backend dependencies (first run)...' -ForegroundColor Yellow
    Push-Location $backend
    npm install
    Pop-Location
}
Start-ServiceWindow -Title 'Backend API   :3000' -WorkingDir $backend -Command 'node server.js'

# Chatbot ---------------------------------------------------------------
$vamp = Join-Path $chatbot '.venv\Scripts\python.exe'
if (-not (Test-Path $vamp)) {
    Write-Host '  creating chatbot virtualenv (first run)...' -ForegroundColor Yellow
    Push-Location $chatbot
    python -m venv .venv
    & '.\.venv\Scripts\python.exe' -m pip install --upgrade pip
    & '.\.venv\Scripts\python.exe' -m pip install -r requirements.txt
    Pop-Location
}
Start-ServiceWindow -Title 'Mentor (Python) :5001' -WorkingDir $chatbot -Command "& '$vamp' app.py"

Write-Host ''
Write-Host 'Waiting for health checks...' -ForegroundColor Cyan

function Test-Url {
    param([string]$Url, [string]$Name)
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $r = Invoke-WebRequest -Uri $Url -TimeoutSec 2 -UseBasicParsing
            if ($r.StatusCode -eq 200) {
                Write-Host "  OK  $Name -> $Url" -ForegroundColor Green
                return $true
            }
        } catch { Start-Sleep -Milliseconds 700 }
    }
    Write-Host "  FAIL $Name -> $Url" -ForegroundColor Red
    return $false
}

$ok1 = Test-Url -Url 'http://127.0.0.1:3000/health' -Name 'Backend API'
$ok2 = Test-Url -Url 'http://127.0.0.1:5001/health' -Name 'Mentor       '

Write-Host ''
if ($ok1 -and $ok2) {
    Write-Host 'Both services are up. Now run the app:' -ForegroundColor Green
    Write-Host "    cd CodeYoung`n    flutter run" -ForegroundColor White
} else {
    Write-Host 'A service did not come up - check the service windows above.' -ForegroundColor Yellow
}
Write-Host ''
