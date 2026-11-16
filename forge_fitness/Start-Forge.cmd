@echo off
cd /d "%~dp0"
if not exist "build\web\index.html" (
  echo Build the computer app first with tools\Build-Forge.ps1.
  pause
  exit /b 1
)
if not exist "server\.env" copy "server\.env.example" "server\.env" >nul
node server\server.mjs
if errorlevel 1 pause

