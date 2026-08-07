@echo off
REM Shows the current status of the test service (stopped/running/etc).
REM Uses the standard Windows "sc" tool, not ProxyBridge_CLI.exe itself.

sc query EPB_TestService
pause
