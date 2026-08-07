@echo off
REM Stops the test service. Requires Administrator rights.

cd /d "%~dp0.."
ProxyBridge_CLI.exe --stop-service --service-name "EPB_TestService"
pause
