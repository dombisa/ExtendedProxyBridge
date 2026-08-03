================================================================================
 EXTENDED PROXYBRIDGE — MANUAL
 A fork of ProxyBridge (InterceptSuite) adding Windows service support
 and automatic proxy failover.
================================================================================


1. WHAT THIS IS
--------------------------------------------------------------------------------
Extended ProxyBridge is a Windows tool that transparently routes selected
applications' network traffic through a SOCKS5 or HTTP proxy, without
having to configure a proxy inside each application separately. It works
at the kernel level via the WinDivert packet-interception driver, not
through Windows' system proxy setting — so it sees traffic even from
programs that ignore system proxy settings entirely.

It's made of two parts:
  - ProxyBridgeCore.dll — the "engine": packet interception, rule
    matching, talking to the proxy servers. Everything important happens
    here.
  - ProxyBridge_CLI.exe — the console front-end: loads the DLL, reads a
    config file (.pbprofile), and controls start/stop, including running
    as a Windows service.

What we added on top of the original project:
  - Full Windows service registration (install/start/stop/uninstall) —
    the original CLI could only run in an open console window.
  - Automatic failover: several proxy servers chained together, a
    background health check, and instant switching to a working one
    without restarting the program.
  - Configurable DNS resolution, per rule: resolve through the proxy
    itself, through your own DNS servers, or through Windows' own DNS —
    in whatever priority order you choose.

Everything else (rules by process, domain, IP, port; full-path matching
to tell apart two identically-named programs; wildcard patterns) was
already in the original ProxyBridge — we left it untouched.


2. FEATURES (FULL LIST)
--------------------------------------------------------------------------------
  * Kernel-level interception via WinDivert — works even with programs
    that ignore Windows' system proxy settings.
  * Up to 16 different proxy configs at once (SOCKS5 and/or HTTP, with
    or without a username/password).
  * Routing rules by:
      - process name (chrome.exe) or FULL PATH
        (C:\Games\Copy1\game.exe) — if the rule contains a backslash,
        the whole path is compared, which lets you tell apart two
        copies of the same program in different folders;
      - destination host (IP, supports wildcards: 192.168.*.*);
      - destination port (a specific port, a comma-separated list, or
        *);
      - domain name (plaintext DNS only — see section 6.4 for the
        limitation, and how the new DnsResolution field can remove it);
      - protocol (TCP / UDP / both).
  * Three actions per rule: PROXY (route through a proxy), DIRECT
    (straight through, bypassing the proxy), BLOCK (deny network access
    entirely for that app/destination).
  * "Smart" rule ordering: a rule with no filters at all
    (ProcessName=*, TargetHosts=*, TargetPorts=*) is ALWAYS evaluated
    last, even if it's first in the file — specific rules automatically
    win over such a fully-open catch-all.
  * Automatic failover (our addition):
      - any proxy can have a "fallback" (FallbackConfigId), and these
        form a chain of any length;
      - a background thread checks whether each proxy server is
        reachable every N seconds with a lightweight TCP connect;
      - traffic automatically switches to the first live proxy in the
        chain if the primary goes down, no manual intervention or
        restart needed;
      - traffic automatically switches back once the primary recovers,
        on the very next check.
  * Configurable DNS resolution (our addition):
      - "proxy" — the domain is never resolved locally; the app gets a
        throwaway address, and the real lookup happens on the proxy
        server itself;
      - "custom" — resolved through DNS servers you specify;
      - "system" — through whatever Windows itself is configured with
        (today's default if left unset);
      - any priority order, any subset of the three.
  * Runs as a Windows service (our addition): install, start, stop,
    remove with one command each — runs in the background with no open
    console, starts automatically on boot.
  * Rename-friendly (our addition): rename the .exe to anything, rename
    the matching .dll to the same name, no recompiling needed.
  * Logging: detailed event log and/or per-connection log (which app,
    where to, through which proxy).
  * Configuration is a plain JSON file (.pbprofile) — editable by hand
    in any text editor.


3. FILES AND WHERE TO PUT THEM
--------------------------------------------------------------------------------
  ProxyBridge_CLI.exe    — the executable, console front-end.
  ProxyBridgeCore.dll    — MUST be in the same folder as the .exe.
  WinDivert.dll          — MUST be in the same folder as the .exe.
  WinDivert64.sys        — MUST be in the same folder as the .exe
                            (kernel driver, for 64-bit systems).
  *.pbprofile             — config files; path is passed via --profile
                            at startup (can live anywhere, doesn't have
                            to be next to the .exe).

All four files (exe + dll + WinDivert.dll + WinDivert64.sys) must be in
the SAME folder. Profiles can be stored separately.

3.1. Renaming the exe and dll (our addition)
--------------------------------------------
You can rename the program to anything — for example, if you'd rather
it not show up in Task Manager as "ProxyBridge_CLI.exe".

The rule is simple: the DLL must be named exactly like the exe, just
with .dll instead of .exe. The program looks at its own filename at
startup and looks for a DLL with that same name next to it — no
recompiling needed.

Example: rename ProxyBridge_CLI.exe to MyAnotherProxy.exe — then
ProxyBridgeCore.dll also needs to become MyAnotherProxy.dll (exactly
that — no "Core" in the name, the whole name matches the exe).
WinDivert.dll and WinDivert64.sys do NOT need renaming (and can't be —
those are third-party driver files).

Verified live under Wine: a renamed exe correctly finds and loads the
renamed DLL, and everything (rules, failover) keeps working unchanged.


4. CLI COMMANDS
--------------------------------------------------------------------------------

4.1. Normal run (in an open console, for testing/debugging)
--------------------------------------------------------------
    ProxyBridge_CLI.exe --profile <path_to_file.pbprofile> [options]

Options:
    --profile <path>      Required. Path to the .pbprofile config file.
    --verbose <0-3>        Optional. Logging level:
                            0 — quiet (only errors and start-up status);
                            1 — general event log (proxy connections,
                                failover toggling, rules being added,
                                etc.);
                            2 — per-connection log (which app, where to,
                                through which proxy, for every single
                                connection);
                            3 — both logs (1 + 2), most verbose, useful
                                when debugging new rules.
                            Default is 0 if not given.

The program runs while the console stays open. Stop it with Ctrl+C or by
closing the console window (both cleanly stop WinDivert before exiting).

Example:
    ProxyBridge_CLI.exe --profile C:\configs\work.pbprofile --verbose 1


4.2. Windows service (our addition) — runs in the background, no console
--------------------------------------------------------------------------

    ProxyBridge_CLI.exe --install-service --profile <path> [--verbose <0-3>]
                        [--service-name <name>] [--service-description <text>]
        Installs a Windows service.
        Default name is "ProxyBridgeExtended" (both internal and
        display name in services.msc are the same), default description
        is a stock Extended ProxyBridge text.
        --service-name sets your own name (both internal and display).
        --service-description sets your own description, visible in
        services.msc's service properties.
        IMPORTANT: if a custom --service-name was used at install time,
        the exact same name must be passed to every later command
        (--start-service, --stop-service, --uninstall-service) — Windows
        looks services up by exact name, the program can't "guess" it.
        Requires administrator rights.
        The profile path is remembered at install time (passed as a
        service startup parameter) — if the profile file is later moved
        or deleted, the service needs to be reinstalled with the new
        path.
        The service is registered with SERVICE_AUTO_START — it comes up
        by itself on the next Windows boot.

    ProxyBridge_CLI.exe --start-service [--service-name <name>]
        Starts an already-installed service.
        Equivalent to: sc start <service_name>

    ProxyBridge_CLI.exe --stop-service [--service-name <name>]
        Stops a running service (WinDivert is shut down cleanly).
        Equivalent to: sc stop <service_name>

    ProxyBridge_CLI.exe --uninstall-service [--service-name <name>]
        Stops (if running) and completely removes the service.
        Requires administrator rights.

Example with a fully custom name and description:
    ProxyBridge_CLI.exe --install-service --profile C:\configs\prod.pbprofile ^
        --service-name "MyCompanyProxy" --service-description "Corporate proxy router"
    ProxyBridge_CLI.exe --start-service --service-name "MyCompanyProxy"
    ...
    ProxyBridge_CLI.exe --uninstall-service --service-name "MyCompanyProxy"


4.3. Utility commands
------------------------
    ProxyBridge_CLI.exe --help
    ProxyBridge_CLI.exe -h
    ProxyBridge_CLI.exe -?
        Shows the full command list with examples.

    ProxyBridge_CLI.exe --version
        Shows the program version.

    ProxyBridge_CLI.exe --update
        Checks GitHub for updates and opens the releases page (inherited
        from the original ProxyBridge — unrelated to our own fork's
        changes, doesn't check for Extended ProxyBridge updates
        specifically).

    ProxyBridge_CLI.exe --service ...
        Internal flag. Used only by the Windows Service Control Manager
        when auto-starting the service — never pass this manually.


5. CONFIG FILE FORMAT (.pbprofile)
--------------------------------------------------------------------------------
It's a plain JSON file. Edit it by hand in any text editor (Notepad,
Notepad++, VS Code, etc.) — just watch the JSON syntax (commas between
fields, quotes around strings, matching braces/brackets).

Notes inside the example files are stored as ordinary JSON fields
"_note" / "_readme" — these are NOT real comments (JSON doesn't support
them), just extra unused keys. You can leave them in the file — the
program just ignores them — or delete them if you don't need them.

5.1. Top-level fields
----------------------------
    "Version"                      String, informational only, not
                                    checked by the program. E.g. "1.0".

    "LocalhostViaProxy"            true / false.
                                    false (recommended) — traffic to
                                    127.0.0.1 never goes through the
                                    proxy, even if a rule would allow
                                    it. Almost always should be false —
                                    most proxies block localhost for
                                    security reasons (SSRF protection),
                                    and if the proxy is on another
                                    machine, localhost traffic wouldn't
                                    make sense there anyway.

    "IsTrafficLoggingEnabled"      true / false.
                                    Enables per-connection logging (with
                                    --verbose 2 or 3 at startup). If
                                    false, even --verbose 2/3 won't
                                    produce the detailed connection log.

    "HealthCheckEnabled"           true / false. (Our addition.)
                                    Enables background health checking
                                    and automatic failover. Defaults to
                                    false — behaviour is identical to
                                    upstream ProxyBridge (no failover).

    "HealthCheckIntervalSeconds"   Number. (Our addition.)
                                    How often to check proxies, in
                                    seconds. Clamped to 5-3600 (values
                                    outside that range are clamped to
                                    the nearest bound). Only matters if
                                    HealthCheckEnabled=true.

    "CustomDnsServers"             String. (Our addition.)
                                    Semicolon-separated "ip:port" list,
                                    e.g. "94.140.14.14:53;9.9.9.9:53".
                                    Used by any rule whose DnsResolution
                                    includes "custom".

    "ProxyConfigs"                 Array of proxy servers. See 5.2.

    "ProxyRules"                   Array of routing rules. See 5.3.


5.2. Fields of one proxy config (inside "ProxyConfigs")
------------------------------------------------------------
    "Id"                  Number. Unique ID for this proxy within the
                           file (you choose it, e.g. 1, 2, 3...).
                           Referenced by rules via ProxyConfigId and by
                           other proxies via FallbackConfigId.

    "Type"                String: "SOCKS5" or "HTTP".
                           IMPORTANT: HTTP proxies don't support UDP —
                           if a rule with Protocol=BOTH or UDP points at
                           an HTTP proxy, the UDP part of that rule's
                           traffic automatically goes DIRECT (bypassing
                           the proxy). Use Protocol="TCP" explicitly on
                           the rule if this matters.

    "Host"                String. IP address or hostname of the proxy
                           server.

    "Port"                STRING (not a number!). E.g. "1080", not
                           1080. This is a quirk of the format — a bare
                           number would still be valid JSON overall, but
                           this particular field won't parse correctly
                           without quotes.

    "Username"             String. Login for proxy authentication.
                           Empty string "" if no auth is needed.

    "Password"             String. Password. Empty string "" if not
                           needed. Stored in plain text in the file —
                           protect the profile file the same way you'd
                           protect a file containing a password.

    "FallbackConfigId"      Number. (Our addition.) Id of another proxy
                           in this same file — where to switch if this
                           proxy fails its health check. 0 or omitted =
                           no fallback. Only takes effect when
                           HealthCheckEnabled=true at the top level.


5.3. Fields of one rule (inside "ProxyRules")
----------------------------------------------------
    "ProcessName"          String. One of:
                              "*"                — any program;
                              "chrome.exe"       — matched by filename
                                                   only (doesn't tell
                                                   apart copies of the
                                                   program in different
                                                   folders);
                              "C:\...\game.exe"  — if the string
                                                   contains a backslash,
                                                   the FULL PATH is
                                                   compared — this is
                                                   how you tell apart
                                                   two copies of an
                                                   identically-named
                                                   program in different
                                                   folders.
                           Several programs in one rule: separated by
                           semicolons, e.g. "chrome.exe;firefox.exe".

    "TargetHosts"           String. "*" (any host), a specific IP, or a
                           wildcard like "192.168.*.*". Several values:
                           separated by semicolons.

    "TargetPorts"           String. "*" (any port), a specific number,
                           or a list separated by commas or semicolons
                           ("80,443" or "80;443;8080").

    "TargetDomains"         String. "" or omitted — no domain
                           restriction (the rule applies regardless of
                           domain). Otherwise — a semicolon-separated
                           list of domain wildcards, e.g.
                           "*.google.com;*.youtube.com". Only works with
                           plaintext DNS (see section 6.4) unless the
                           rule's DnsResolution includes "proxy" — see
                           section 6.4 for how that removes the
                           limitation.

    "Protocol"              String: "TCP", "UDP", or "BOTH".

    "Action"                String: "PROXY" (route through a proxy),
                           "DIRECT" (straight through, bypassing the
                           proxy), "BLOCK" (deny network access
                           entirely).

    "ProxyConfigId"         Number. Required only when Action="PROXY" —
                           which Id from "ProxyConfigs" to use. Doesn't
                           matter for DIRECT and BLOCK, can be left 0.

    "IsEnabled"             true / false. Lets you temporarily disable a
                           rule without deleting it from the file
                           (handy while debugging — flip a rule off and
                           back on with one word).

    "DnsResolution"         String. (Our addition.) Semicolon-separated
                           priority list of "proxy", "custom", "system",
                           e.g. "proxy;custom;system". Omitted or empty
                           = no DNS interception at all for this
                           process (today's original behaviour). See
                           section 6.7 for a full walkthrough.


6. USAGE SCENARIOS, WALKED THROUGH
--------------------------------------------------------------------------------

6.1. The simplest case: one app through a proxy
---------------------------------------------------------
Goal: only Telegram goes through a local SOCKS5 (e.g. a Tor or VPN
client's port on 127.0.0.1:9050), everything else on the machine works
normally, direct.

File: 1_single_app_socks5.pbprofile.

Key idea: one PROXY rule for Telegram.exe + one (optional, but explicit)
catch-all DIRECT rule for everything else. By default, if no rule
matches, traffic already goes direct — the explicit catch-all rule is
just there to document the intent in the file itself.

How to check it's working: run with --verbose 2, open Telegram, and the
log should show connections specifically from Telegram.exe going
through the proxy. Other programs shouldn't show up in that log at all
(or should show as DIRECT, if a separate rule covers them).


6.2. Several apps, different proxies
-------------------------------------------
Goal: a work browser goes through one SOCKS5 (e.g. a corporate VPN
gateway), a torrent client through a separate HTTP proxy with a
username/password, everything else direct.

File: 2_multi_app_multi_proxy.pbprofile.

Key idea: two independent entries in "ProxyConfigs" (Id=1 and Id=2), and
rules point at different ProxyConfigId values. Important detail: if the
torrent client uses both TCP and UDP (it usually does), and its proxy is
HTTP-type, set Protocol="TCP" on that rule explicitly — HTTP proxies
can't proxy UDP, and without an explicit TCP setting the program sends
the UDP part direct on its own, which can be unexpected for torrent
traffic (DHT, peer exchange over UDP staying visible unproxied).


6.3. Telling apart identically-named programs by full path
---------------------------------------------------------------------
Goal: two installs of the same program (e.g. two copies of a game
launcher, game.exe — a work copy in one folder, a test copy in
another), and only one of the copies should go through the proxy.

File: 3_duplicate_named_apps_by_path.pbprofile.

Key idea: "ProcessName" contains the FULL PATH with a backslash (e.g.
"C:\\Games\\WorkCopy\\game.exe" — in JSON a backslash needs to be
double-escaped, so it appears as "\\\\" in the raw file, or "\\" when
viewed in a text editor). Without a backslash, only the filename is
compared, and both copies would be treated as the same program — there
would be no way to tell them apart.

Practical tip: to find a running process's exact path, check Task
Manager (Details tab → right-click the process → "Open file location"),
or PowerShell:
    Get-Process game | Select-Object Path


6.4. Domain-based routing within a single app
---------------------------------------------------------
Goal: Chrome goes through a proxy only when talking to specific domains
(e.g. only Google services), other sites in the same browser go direct.

File: 4_domain_based_routing.pbprofile.

Key idea: two rules for chrome.exe — one with TargetDomains filled in
(order relative to the other doesn't matter, see 6.6), the second with
an empty TargetDomains as a "catch everything else for Chrome".

THE OLD LIMITATION (how the underlying mechanism used to work, still
true if you don't use DnsResolution): domain filtering worked by
"sniffing" ordinary plaintext DNS queries (port 53, UDP) as they passed
by. If DNS-over-HTTPS (DoH) or DNS-over-TLS (DoT) is enabled in Windows
— i.e. the DNS queries themselves travel over an encrypted channel — the
program never saw them, and the domain rule simply never matched: the
"this IP = this domain" link was never made, and the traffic was treated
as "domain unknown" (equivalent to failing the TargetDomains filter).

THIS IS SOLVED NOW: add "DnsResolution": "proxy;system" (or similar) to
the rule (see profile 4 for a worked example). The program then
intercepts Chrome's own DNS query itself and resolves it on its own —
DoH/DoT being on or off in Windows no longer matters, because Chrome's
real DNS query never actually reaches the network at all. One important
nuance: that field sits on the FIRST matching PROXY rule for chrome.exe
in the file — so it governs DNS resolution for ALL of Chrome's domain
lookups, not just the ones matching TargetDomains. This is expected: the
decision of "should we intercept DNS for this process" is made once per
process, not per destination — the program can't yet know what domain
is being asked about before it decides whether to intercept it.


6.5. Blocking an app + "proxy everything except exceptions"
------------------------------------------------------------------
Goal: one specific program should have no network access at all; the
local network (router, NAS, printer, other devices at home/work) should
work direct; everything else on the machine goes through the proxy by
default.

File: 5_block_and_catchall_with_lan_exception.pbprofile.

Key idea — an important feature that makes this scenario possible
without manually sorting rules by position: a rule where
ProcessName=*, TargetHosts=*, and TargetPorts=* ALL AT ONCE (i.e. no
filter whatsoever) is ALWAYS checked LAST by the program, no matter
where it physically sits in the file. So:
    - a BLOCK rule for a specific program (with its own ProcessName)
    - a DIRECT rule for local subnets (with its own TargetHosts)
always "win" over a fully-open catch-all PROXY rule, in any file order.
You can freely append new exceptions to the end of the file without
worrying about where exactly to place them relative to the catch-all.


6.6. Rule order and priority — how it actually works
------------------------------------------------------------------------
Rules are checked top to bottom, and the FIRST matching rule decides the
action for a connection — with one important exception (see 6.5): a rule
with no filters at all is always deferred to the very end of the check
order, even if it's physically first in the file.

From this it follows:
    - if two rules for the same program could both match the same
      connection, whichever comes first in the file wins (except the
      fully-open rule, which is always checked last);
    - if a rule doesn't match on one of its conditions (e.g. the process
      matches but the domain doesn't), the program does NOT stop
      checking — it just moves on to the next rule, as if this one
      didn't exist; so you can freely stack several rules for the same
      program, they won't interfere with each other, each is checked on
      its own conditions independently;
    - if nothing at all matches, traffic goes direct (an implicit
      DIRECT).


6.7. Automatic failover between proxies
------------------------------------------------
Goal: if the primary proxy goes down (unreachable), traffic
automatically switches to a backup, no manual action needed; once the
primary comes back up, traffic switches back to it automatically.

File: 6_automatic_failover.pbprofile.

Key idea: "HealthCheckEnabled": true + "HealthCheckIntervalSeconds" at
the top level turn on background checking. Proxy Id=1 gets
"FallbackConfigId": 2 — if it's "down", proxy Id=2 is used instead. The
chain can continue: proxy Id=2 can in turn have its own
FallbackConfigId=3, and so on — up to 16 proxies in the chain (the
overall limit on proxy configs per file).

How liveness is checked: every N seconds, the program does an ordinary
TCP connect to the proxy server's own port (not real traffic, no
handshake) — a fast, lightweight check of "is the service itself up",
rather than "is some specific site reachable through it".

What happens if ALL proxies in the chain are down at once: traffic goes
DIRECT (as if no proxy were configured at all), rather than being
blocked. This is a deliberate choice favouring availability — if your
scenario cares more about "no internet is better than leaking my real
IP" (e.g. working with a VPN/anti-censorship proxy where a direct
connection reveals identity or location), this behaviour should change
to BLOCK-on-total-failure instead — let us know, that would need a
separate addition; it isn't configurable through the profile right now.

Limitation: failover is our addition, it only works with the
ProxyBridgeCore.dll from this fork. With the official upstream DLL from
InterceptSuite, the HealthCheckEnabled/FallbackConfigId fields are just
read and ignored (the program won't break, but nothing happens either)
— the CLI itself detects this (via the absence of the needed functions
in the DLL) and prints a warning at the appropriate verbosity level.


6.8. Configurable DNS resolution
-------------------------------------
Goal: control HOW an application's own DNS lookups happen — through the
proxy itself, through your own DNS servers, through Windows' own DNS —
with a fallback order, entirely optional and per rule.

File: 7_dns_resolution_priority_modes.pbprofile.

Three sources, any priority order, any subset:

  - "proxy" — the domain is never resolved locally at all. The
    application is handed a temporary "fake" IP from the 198.18.0.0/15
    range (officially reserved for testing, never routed on a real
    network — the same range Clash/V2Ray/Xray use for this exact
    purpose). The real address is found by the proxy server itself once
    the app connects (the domain name is passed straight to it, which
    SOCKS5 supports natively).
  - "custom" — resolved through your own DNS servers
    ("CustomDnsServers": "94.140.14.14:53;9.9.9.9:53" at the top level
    of the profile). A dedicated hand-rolled DNS client, built and
    parsed by hand.
  - "system" — through whatever Windows itself is configured with
    (default behaviour if DnsResolution is omitted).

Example: "DnsResolution": "proxy;custom;system" means: try resolving
through the proxy first; if that fails, try the custom DNS servers; if
those also fail, fall back to Windows' own DNS.

Technically: interception happens at the WinDivert level (a query to
port 53 from a process with a configured policy is dropped, and a
response is built by hand and injected back); each query is handled on
its own separate worker thread — the single packet-processing thread
(there's only one for the whole program) is never blocked waiting on
network I/O.

Verified live under Wine: the whole chain from the JSON profile through
to the policy being applied in the DLL (log line: "Rule ID N DNS
resolution policy set"), the custom DNS client against a real DNS
server (successful resolution and correct NXDOMAIN handling), and the
fake-IP pool's arithmetic (the full range, no collisions). NOT verified
and can't be verified in a sandbox: the actual packet injection into a
real Windows network stack under a genuine WinDivert driver — this is
the highest-risk part of the whole project, make sure to test it first
on a real machine before relying on it.


6.9. Typical Windows service deployment
--------------------------------------------------------
Goal: keep proxy routing running permanently, in the background, coming
up automatically on reboot, without needing an open console or being
logged in as a specific user.

Steps:
    1. Put all 4 files (ProxyBridge_CLI.exe, ProxyBridgeCore.dll,
       WinDivert.dll, WinDivert64.sys) in a permanent folder, e.g.
       C:\Program Files\ExtendedProxyBridge\ (not a temp folder or
       Downloads — the service needs a stable path to refer to).
    2. Prepare the .pbprofile you need and put it somewhere permanent
       too (can be the same folder).
    3. From an Administrator command prompt:
           cd "C:\Program Files\ExtendedProxyBridge"
           ProxyBridge_CLI.exe --install-service --profile "C:\Program Files\ExtendedProxyBridge\myconfig.pbprofile"
    4. Start the service:
           ProxyBridge_CLI.exe --start-service
    5. Check status:
           sc query ProxyBridgeExtended
       Expected state: RUNNING.

To change the config of an already-installed service (e.g. add a new
rule):
    1. Edit the .pbprofile file itself (the path hasn't changed — just
       change the contents).
    2. Restart the service so it re-reads the file:
           ProxyBridge_CLI.exe --stop-service
           ProxyBridge_CLI.exe --start-service
       (The service doesn't watch the file for live changes — config is
       read once at startup.)

To remove the service entirely and go back to running it manually:
    ProxyBridge_CLI.exe --uninstall-service


7. TROUBLESHOOTING
--------------------------------------------------------------------------------

"ERROR: Administrator privileges required"
    Run the command prompt or the .exe as Administrator (right-click →
    "Run as administrator"). WinDivert needs kernel-level network driver
    access, which is simply impossible without administrator rights.

"Failed to open WinDivert" / "Ensure WinDivert64.sys is present"
    Make sure WinDivert.dll and WinDivert64.sys are in the SAME folder
    as ProxyBridge_CLI.exe and ProxyBridgeCore.dll — all four files
    together, always. Also check you're really running as Administrator
    (see above), and that Windows' "Core Isolation" / "Memory
    Integrity" feature isn't set to a mode that blocks unsigned or
    third-party drivers — in some configurations it interferes with
    loading WinDivert.

"ERROR: No profile specified"
    The --profile <path> argument is missing. Running with no arguments
    at all only shows --help.

The program runs but a rule doesn't seem to apply
    - Check with --verbose 2-3 — the log should show which rule a given
      connection matched (or that it matched none).
    - Check ProcessName — if the rule only has a filename (no path) and
      the program actually lives in two places (or was updated and
      changed path), a path-based rule might unexpectedly not match.
    - For domain rules (TargetDomains) — check whether DoH/DoT is
      enabled (see section 6.4), or add DnsResolution to bypass that
      limitation entirely.
    - For UDP traffic through an HTTP proxy — check the rule's Protocol
      setting (see section 6.2).

The service installs but won't start
    Run `sc query ProxyBridgeExtended` and check the exit code
    (WIN32_EXIT_CODE). Common causes: an incorrect/moved profile path
    (the service stores the absolute path fixed at the time of
    --install-service), or the account the service runs under lacking
    rights (Local System usually has enough, but corporate security
    policies can restrict this).

Need the exact path of a running process (for path-based rules)
    PowerShell:
        Get-Process <name_without_exe> | Select-Object Path
    Or Task Manager → Details tab → right-click the process → "Open
    file location".


8. IMPORTANT CAVEATS AND HONEST TESTING BOUNDARIES
--------------------------------------------------------------------------------
Everything described in this manual was actually compiled via
mingw-w64 (cross-compiling in a Linux sandbox) — not just written "on
faith". The .pbprofile parsing logic, Windows service handling
(registration, start/stop via the Service Control Manager), and the
failover mechanism (live/dead proxy detection, switching) were further
verified live via Wine against real TCP sockets — meaning these aren't
theoretical claims, they're the result of actual runs.

What genuinely could NOT be tested in that environment (there's no real
Windows there, and there can't be a real Windows kernel driver):
    - actual traffic passing through WinDivert;
    - actual DNS-query interception and spoofed-response injection at
      the packet level (the riskiest part of the whole project);
    - behaviour of a real Windows service across reboots, user
      switches, hibernation;
    - behaviour with "Core Isolation"/Memory Integrity enabled;
    - long-term service stability over weeks/months.

These need checking on a real machine. If something doesn't work as
expected, please open an issue with the exact error text, the `sc
query` exit code, or `--verbose 3` output — we'll fix it based on facts,
not guesses.

================================================================================
