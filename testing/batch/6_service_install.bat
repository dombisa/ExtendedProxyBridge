@echo off
REM Installs Extended ProxyBridge as a Windows service, using the basic
REM test config and a clearly test-only service name so you don't
REM confuse it with a real deployment.
REM Requires Administrator rights.

cd /d "%~dp0.."
ProxyBridge_CLI.exe --install-service --profile configs\basic.pbprofile --service-name "EPB_TestService" --service-description "Extended ProxyBridge - manual test install"
pause
