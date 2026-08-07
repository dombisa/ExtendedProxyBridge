@echo off
REM Starts the service installed by 6_service_install.bat.
REM Requires Administrator rights.

cd /d "%~dp0.."
ProxyBridge_CLI.exe --start-service --service-name "EPB_TestService"
pause
