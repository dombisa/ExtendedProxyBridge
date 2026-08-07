@echo off
REM Same as 1_run_basic.bat but with maximum log detail (--verbose 3):
REM both the general event log AND the per-connection log.
REM Useful when you need to see exactly what's happening, not just that
REM it started.
REM
REM SETUP: same as 1_run_basic.bat - exe/dll files go in the "testing"
REM folder, one level above this "batch" folder.

cd /d "%~dp0.."
ProxyBridge_CLI.exe --profile configs\basic.pbprofile --verbose 3
pause
