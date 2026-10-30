@echo off
setlocal DisableDelayedExpansion
chcp 65001 >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dpn0.ps1" %*
set "JOBS_EXIT_CODE=%ERRORLEVEL%"
if not "%JOBS_NO_PAUSE%"=="1" pause
exit /b %JOBS_EXIT_CODE%
