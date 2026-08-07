@echo off
REM Proxy chaining check: hop1 (SOCKS5) is set up to chain through hop2 (HTTP).
REM Watch the startup log for:
REM   "Proxy config ID 1 chains -> 2"
REM
REM configs\chain.pbprofile points at 127.0.0.1:9401/9402, which won't
REM have anything listening unless you set up test proxies there - this
REM is enough to confirm the chain link itself gets registered correctly
REM even without live proxies.
REM
REM SETUP: same as 1_run_basic.bat.

cd /d "%~dp0.."
ProxyBridge_CLI.exe --profile configs\chain.pbprofile --verbose 1
pause
