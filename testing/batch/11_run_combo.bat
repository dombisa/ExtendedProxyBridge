@echo off
REM Runs the "everything at once" combo profile: failover + chaining +
REM custom DNS + per-rule DNS policy + path-based rules + domain rules +
REM LAN exception + block + catch-all, all in one config. Good final
REM check that nothing conflicts once every feature is turned on together.
REM
REM SETUP: same as 1_run_basic.bat.

cd /d "%~dp0.."
ProxyBridge_CLI.exe --profile configs\combo.pbprofile --verbose 3
pause
