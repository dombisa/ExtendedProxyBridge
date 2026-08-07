@echo off
REM DNS resolution check: three test apps, one per DnsResolution priority
REM order (proxy-first / custom-first / system-only).
REM Watch the startup log for:
REM   "Custom DNS server added: ..."           (CustomDnsServers parsed)
REM   "Rule ID N DNS resolution policy set (...)"  (once per rule that has DnsResolution)
REM
REM SETUP: same as 1_run_basic.bat.

cd /d "%~dp0.."
ProxyBridge_CLI.exe --profile configs\dns_resolution.pbprofile --verbose 1
pause
