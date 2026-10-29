@echo off
REM Menjalankan TradingBot AI. Versi awal; langkah 23b mengganti perintah ini dengan watchdog.
cd /d "%~dp0"
if not exist .venv\Scripts\python.exe (
  echo Virtualenv .venv belum ada. Jalankan scripts\setup_vps.ps1 sebagai Administrator.
  exit /b 1
)
.venv\Scripts\python.exe -m tradingbot %*
