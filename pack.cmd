@echo off
REM Usage: pack dex_radar
setlocal
cd /d "%~dp0"
where python >nul 2>&1 && (
  python "%~dp0pack.py" %*
  exit /b %ERRORLEVEL%
)
where python3 >nul 2>&1 && (
  python3 "%~dp0pack.py" %*
  exit /b %ERRORLEVEL%
)
echo Python not found on PATH.
exit /b 1
