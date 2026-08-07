@echo off
REM Failover check: two proxies, 5-second health check interval.
REM Watch the log for lines like:
REM   "Health check: proxy config ID 1 (...) went DOWN"
REM   "Health check: proxy config ID 1 (...) is back UP"
REM (You'll only see those if the proxy in configs\failover.pbprofile is
REM actually reachable/unreachable during the test - edit the Host/Port
REM in that file to point at something real you control, e.g. a proxy
REM you can start and stop while this is running.)
REM
REM SETUP: same as 1_run_basic.bat.

cd /d "%~dp0.."
ProxyBridge_CLI.exe --profile configs\failover.pbprofile --verbose 1
pause
