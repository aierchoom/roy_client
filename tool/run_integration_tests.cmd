@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_integration_tests.ps1" %*
exit /b %ERRORLEVEL%
