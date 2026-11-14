@echo off
REM ==========================================================================
REM  CodeYoung - start the Python mentor service (voice chatbot)
REM  Run from the repository root:   scripts\start-chatbot.cmd
REM  Requires: Python 3.11+
REM ==========================================================================
setlocal
cd /d "%~dp0..\chatbot"

if not exist ".venv" (
  echo [chatbot] creating virtual environment...
  python -m venv .venv
  if errorlevel 1 (
    echo [chatbot] could not create a virtual environment.
    exit /b 1
  )
)

call ".venv\Scripts\activate.bat"

if not exist ".venv\.installed" (
  echo [chatbot] installing dependencies...
  python -m pip install --upgrade pip >nul
  python -m pip install -r requirements.txt
  if errorlevel 1 (
    echo [chatbot] dependency install failed.
    exit /b 1
  )
  echo. > ".venv\.installed"
)

echo [chatbot] starting on http://127.0.0.1:5001
python app.py
endlocal
