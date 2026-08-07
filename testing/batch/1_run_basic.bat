@echo off
REM Basic interactive run - the simplest possible check.
REM
REM SETUP: copy ProxyBridge_CLI.exe, ProxyBridge_CLI.dll, WinDivert.dll,
REM and WinDivert64.sys directly into the "testing" folder (the parent
REM of the "batch" folder this .bat file lives in) - NOT into "batch"
REM itself. The "configs" folder is already where it needs to be.
REM
REM Requires Administrator rights (right-click this file -> Run as
REM administrator, or run it from an Administrator command prompt).
REM
REM Expected: starts up, parses configs\basic.pbprofile, then either:
REM   - fails at "Failed to open WinDivert" if not run as Administrator, or
REM   - actually starts if run correctly with WinDivert.dll/WinDivert64.sys present.
REM Stop with Ctrl+C.

cd /d "%~dp0.."
ProxyBridge_CLI.exe --profile configs\basic.pbprofile --verbose 1
pause
