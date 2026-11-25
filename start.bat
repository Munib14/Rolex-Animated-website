@echo off
title The Art of Precision - local preview
cd /d "%~dp0"

echo.
echo   ==========================================
echo     THE ART OF PRECISION
echo   ==========================================
echo.

where node >nul 2>&1
if errorlevel 1 (
  echo   Node.js was not found on this computer.
  echo   Install it from https://nodejs.org then run this file again.
  echo.
  pause
  exit /b 1
)

if not exist "node_modules\" (
  echo   First run: installing dependencies. This takes a minute...
  echo.
  call npm.cmd install
  if errorlevel 1 (
    echo.
    echo   Install failed. Check your internet connection, then try again.
    pause
    exit /b 1
  )
)

echo   Starting the server...
echo.
echo   Address:  http://localhost:3000
echo   To stop:  close this window, or press Ctrl+C
echo.
echo   Your browser will open by itself in a few seconds.
echo.

start "" /b powershell -NoProfile -WindowStyle Hidden -Command "Start-Sleep -Seconds 10; Start-Process 'http://localhost:3000'"

call npm.cmd run dev

echo.
echo   Server stopped.
pause
