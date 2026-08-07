@echo off
REM Stops (if running) and removes the test service entirely.
REM Requires Administrator rights.
REM Run this when you're done testing the service, so it doesn't linger
REM on your system as a real auto-starting service.

cd /d "%~dp0.."
ProxyBridge_CLI.exe --uninstall-service --service-name "EPB_TestService"
pause
