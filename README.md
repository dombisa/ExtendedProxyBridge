# Extended ProxyBridge

A fork of [ProxyBridge](https://github.com/InterceptSuite/ProxyBridge) by
Sourav Kalal / InterceptSuite, adding Windows service support, automatic
proxy failover, configurable DNS resolution (including resolving through
the proxy itself), and rename-friendly builds.

ProxyBridge transparently routes selected Windows applications' traffic
through a SOCKS5 or HTTP proxy at the kernel level, via
[WinDivert](https://github.com/basil00/WinDivert) packet interception —
no per-application proxy configuration needed, and no TUN adapter.

This fork keeps everything the original project already does (per-process
and per-path rules, host/port wildcards, domain-based rules, TCP/UDP) and
adds the features below.

## What this fork adds

- **Windows service support** — install/start/stop/uninstall as a proper
  Windows service, with a customizable service name and description. Runs
  headless, no open console needed, starts automatically on boot.
- **Automatic failover** — chain multiple proxy configs together; a
  background health-check thread detects when one goes down and switches
  traffic to the next one in the chain automatically, then switches back
  once it recovers.
- **Configurable DNS resolution**, per rule, with three interchangeable
  sources and a priority order you choose:
  - `proxy` — the domain is never resolved locally at all. The application
    is handed a throwaway address from the 198.18.0.0/15 range (RFC 2544
    benchmark range, non-routable, the same convention used by
    Clash/V2Ray/Xray for this exact purpose); the real lookup happens on
    the proxy server itself via a SOCKS5 domain-based CONNECT.
  - `custom` — resolved through your own DNS servers, via a hand-rolled
    DNS client (Windows doesn't expose a supported way to point
    `getaddrinfo()` at a specific server).
  - `system` — whatever DNS servers Windows itself is configured with
    (today's default behaviour if this field is left unset).
- **Proxy chaining** — connect through one proxy, tunnel through another,
  reach the real destination through as many hops as you configure, and
  freely mix SOCKS5 and HTTP proxies within the same chain (e.g.
  SOCKS5 → HTTP → the real site). Verified end to end against real
  SOCKS5 and HTTP proxy implementations, both hop orderings, with real
  data actually flowing through the tunnel — not just a successful
  handshake.
- **Rename-friendly builds** — rename the .exe to anything, rename the
  matching .dll to the same name, and it just works. No hardcoded file
  names, no recompiling.

## Status / how far this has been tested

Everything above was actually compiled with `x86_64-w64-mingw32-gcc`
(cross-compiled from Linux) and, where possible, exercised against real
sockets under Wine: health-check detection against a live/dead TCP
listener, the hand-rolled DNS client against a real DNS server (including
correctly handling NXDOMAIN), the service install/start/stop/uninstall
cycle against Wine's Service Control Manager, full `.pbprofile` → CLI →
DLL wiring for every feature above, and proxy chaining against real
minimal SOCKS5 and HTTP proxy implementations (both hop orderings, with
actual application data verified flowing through the tunnel, not just a
successful handshake). The spoofed DNS response packet
itself — the exact bytes that would get handed to `WinDivertSend` — is
now verified field-by-field (IP header version/length/protocol/spoofed
source address, UDP ports/length, DNS transaction ID/flags/answer count,
the question section copied verbatim, the answer record's name pointer/
type/class/TTL/length/IP) on **both** x64 and x86 builds, byte-identical
between them.

**What could not be tested in that environment, and needs verification on
real Windows before you rely on it:** actually calling `WinDivertOpen()`/
`WinDivertSend()` against a real kernel driver — i.e. whether the
correctly-built packet above actually gets delivered the way it's
supposed to. Wine has no real kernel driver, so `WinDivertOpen()` always
fails there; that one call is the ceiling on what a sandbox can verify
here, everything upstream of it (packet construction, field layouts
checked against the real WinDivert SDK headers, byte-level DNS parsing)
has been. If you hit issues, please open an issue with `--verbose 3` output.

## Architecture and Windows version

**Both 64-bit (x64) and 32-bit (x86) builds are available**, built from
the identical source. Compiled with `x86_64-w64-mingw32-gcc` and
`i686-w64-mingw32-gcc` respectively, and both were actually run (not
just compiled) under Wine — the 32-bit build needed a dedicated
`WINEARCH=win32` Wine prefix to test at all, since a normal 64-bit Wine
prefix can't run 32-bit binaries without one. Along the way this caught
a real pre-existing bug in upstream ProxyBridge's CLI (a missing
`#include <shellapi.h>` that happened to still link on x64 by luck, but
failed outright on x86) — fixed in both builds here.

**Minimum Windows version: Windows 7** (not Vista/Server 2008). This
isn't a guess: it comes directly from two things lining up — WinDivert
2.2.2's own upstream README states it supports "Windows 7, Windows 8 and
Windows 10" (older WinDivert 1.x docs mention Vista/Server 2008, but
that's a different, older version of WinDivert, not the one this project
uses), and this fork's own code is compiled with `_WIN32_WINNT=0x0601`
(the Windows 7 API baseline) — so both the driver dependency and our own
build target agree on Windows 7 as the floor. Windows 8/8.1/10/11 should
all work too (WinDivert explicitly supports them); nothing about this
fork's own additions should narrow that range further, but only Windows
10/11 has actually been used during development.

Vista/Server 2008 support hasn't been attempted and isn't planned right
now, but was looked into — see [`docs/VISTA_COMPATIBILITY.md`](docs/VISTA_COMPATIBILITY.md)
for a concrete assessment of what it would take and how risky it looks,
in case that need comes up later.

## Download / build

Pre-built binaries: [`prebuilt/`](prebuilt) (compiled straight from the
source in this repo — you still need to add WinDivert's own files, see
[`prebuilt/README.md`](prebuilt/README.md)).

To build yourself (Linux, cross-compiling with mingw-w64):

```bash
sudo apt install gcc-mingw-w64-x86-64 gcc-mingw-w64-i686
curl -sLO https://github.com/basil00/WinDivert/releases/download/v2.2.2/WinDivert-2.2.2-A.zip
unzip WinDivert-2.2.2-A.zip

# ── x64 ──────────────────────────────────────────────────────────────
x86_64-w64-mingw32-gcc -std=gnu11 -shared -O2 -D_WIN32_WINNT=0x0601 -DPROXYBRIDGE_EXPORTS \
  -I WinDivert-2.2.2-A/include Windows/src/ProxyBridge.c \
  -L WinDivert-2.2.2-A/x64 -lWinDivert -lws2_32 -liphlpapi \
  -o ProxyBridgeCore.dll

x86_64-w64-mingw32-gcc -std=gnu11 -O2 -D_WIN32_WINNT=0x0601 \
  Windows/cli/main.c -lwinhttp -lshell32 -ladvapi32 \
  -o ProxyBridge_CLI.exe

# ── x86 ──────────────────────────────────────────────────────────────
i686-w64-mingw32-gcc -std=gnu11 -shared -O2 -D_WIN32_WINNT=0x0601 -DPROXYBRIDGE_EXPORTS \
  -I WinDivert-2.2.2-A/include Windows/src/ProxyBridge.c \
  -L WinDivert-2.2.2-A/x86 -lWinDivert -lws2_32 -liphlpapi \
  -o ProxyBridgeCore32.dll

i686-w64-mingw32-gcc -std=gnu11 -O2 -D_WIN32_WINNT=0x0601 \
  Windows/cli/main.c -lwinhttp -lshell32 -ladvapi32 \
  -o ProxyBridge_CLI32.exe
```

Copy `ProxyBridgeCore.dll`, `ProxyBridge_CLI.exe`, `WinDivert.dll`, and
`WinDivert64.sys` (from the WinDivert release zip's `x64/` folder) into
the same directory on a Windows machine for the x64 build — or the x86
equivalents plus **both** `WinDivert32.sys` and `WinDivert64.sys` (see
[`prebuilt/README.md`](prebuilt/README.md) for why both) for the x86
build. Administrator rights are required either way (WinDivert needs
kernel-level access).

## Documentation

- [`docs/README.txt`](docs/README.txt) — full manual: every CLI command,
  every `.pbprofile` field, walkthroughs for every usage scenario,
  troubleshooting.
- [`profiles/`](profiles) — nine annotated example `.pbprofile` files
  covering single-app proxying, multiple proxies, path-based rules,
  domain-based routing, blocking + LAN exceptions, automatic failover,
  and the three DNS resolution priority modes.
- [`NOTICE.md`](NOTICE.md) — summary of what's new in this fork versus
  upstream ProxyBridge.

## Configuration format

Config files are plain JSON (`.pbprofile`). See
[`docs/README.txt`](docs/README.txt) for the full field reference, or
jump straight to the [`profiles/`](profiles) folder for working examples
with inline explanations.

## License

MIT, same as upstream ProxyBridge — see [`LICENSE`](LICENSE). This is a
fork, not an original work from scratch; full credit to
[InterceptSuite/ProxyBridge](https://github.com/InterceptSuite/ProxyBridge)
for the original project this builds on.

## Known limitations / roadmap

- DNS interception is unverified on real hardware (see Status above).
- IPv6 fake-IP addresses (AAAA queries) are not handled yet — the `proxy`
  DNS source only answers A queries; the application falls back to its
  own IPv4 path.
- Proxy chaining's intermediate hops are always dialled as plain IPv4,
  even if the final destination is IPv6 or a cached domain name — proxy
  servers are overwhelmingly deployed with an IPv4 address of their own
  regardless of what traffic they carry, so this keeps chaining
  tractable. The final hop is unaffected and keeps full IPv6/domain
  support exactly as before chaining existed.
