# NOTICE — differences from upstream ProxyBridge

This is a fork of [InterceptSuite/ProxyBridge](https://github.com/InterceptSuite/ProxyBridge),
used under the terms of its MIT license (see `LICENSE`). All credit for the
original design — WinDivert-based kernel-level interception, the rule
engine, per-process/path/host/port/domain matching, the SOCKS5/HTTP proxy
client code, the `.pbprofile` format — belongs to the upstream project and
its author, Sourav Kalal / InterceptSuite.

## What was added in this fork

- **Windows service support**: `--install-service`, `--uninstall-service`,
  `--start-service`, `--stop-service`, with `--service-name` and
  `--service-description` for full customization. Upstream ProxyBridge's
  CLI only ran interactively in an open console.
- **Automatic failover**: `ProxyBridge_SetProxyFallback`,
  `ProxyBridge_SetHealthCheckEnabled`, `ProxyBridge_IsProxyHealthy` in the
  core DLL; `FallbackConfigId`, `HealthCheckEnabled`,
  `HealthCheckIntervalSeconds` in `.pbprofile`.
- **Configurable DNS resolution**: `ProxyBridge_SetCustomDnsServers`,
  `ProxyBridge_SetRuleDnsResolution`, `ProxyBridge_ResolveViaCustomDns`,
  plus the fake-IP pool and WinDivert-level DNS query interception/
  response injection; `CustomDnsServers` and per-rule `DnsResolution` in
  `.pbprofile`.
- **Rename-friendly builds**: the CLI resolves its DLL's filename from its
  own filename at runtime instead of a hardcoded `ProxyBridgeCore.dll`.

## What was intentionally left unchanged

Everything else — the rule matching engine (including the "fully-open
wildcard rules are always evaluated last" behaviour), wildcard/path/domain
matching, the proxy client handshakes, UDP relay, connection logging — is
upstream ProxyBridge's code, unmodified except where noted above (e.g. the
DNS-source substitution point inside `check_process_rule()`).
