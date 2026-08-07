# Manual testing kit

Ready-to-run `.bat` files and matching minimal `.pbprofile` configs, one
feature at a time, so you can check "does X actually work on my machine"
without hand-writing a config or command line first. These are separate
from the story-based examples in [`../profiles/`](../profiles) — those
show realistic setups, these are deliberately minimal and single-purpose.

## Setup (do this first)

Copy `ProxyBridge_CLI.exe`, `ProxyBridge_CLI.dll` (from
[`../prebuilt/x64/`](../prebuilt/x64) or
[`../prebuilt/x86/`](../prebuilt/x86) depending on your system — see the
main README if unsure which), `WinDivert.dll`, and `WinDivert64.sys`
(from the official WinDivert release, see `../prebuilt/README.md`)
directly into **this `testing` folder** — the same folder this
`README.md` is in, one level above `batch/` and `configs/`. Don't put
them inside `batch/` itself.

Once that's done, every `.bat` file in `batch/` can just be
double-clicked (or right-clicked → "Run as administrator", which most
of these need — WinDivert requires it).

## What each one checks

| File | What it checks |
|---|---|
| `1_run_basic.bat` | Bare minimum: starts, loads the DLL, parses a config. If this fails, nothing else will work either — fix this first. |
| `2_run_verbose.bat` | Same, but with `--verbose 3` (maximum log detail) — useful once `1` works and you want to see everything. |
| `3_test_failover.bat` | Failover: two proxies, 5-second health check. Watch for "went DOWN" / "is back UP" lines. |
| `4_test_dns.bat` | DNS resolution: three test apps, one per priority order (`proxy;custom;system`, `custom;system`, `system`). Watch for "Custom DNS server added" and "DNS resolution policy set" lines. |
| `5_test_chain.bat` | Proxy chaining: watch for "Proxy config ID 1 chains -> 2". |
| `6_service_install.bat` | Installs a Windows service named `EPB_TestService` (clearly test-only, won't be confused with a real deployment). |
| `7_service_start.bat` | Starts it. |
| `8_service_status.bat` | Shows its current state via the standard `sc query` tool. |
| `9_service_stop.bat` | Stops it. |
| `10_service_uninstall.bat` | Removes it entirely — **run this when you're done testing the service**, so it doesn't linger as a real auto-starting service on your machine. |
| `11_run_combo.bat` | Everything at once (failover + chaining + DNS + rules) — final sanity check that nothing conflicts. |

## What "success" looks like

None of the test configs point at real, reachable proxy servers (the
addresses are placeholders) — that's intentional, this kit checks that
the *program* behaves correctly (parses configs, registers rules,
enables features, tries to start WinDivert), not that some specific
proxy service is reachable right now. Every script is expected to reach
either:

- `Failed to open WinDivert` / `Ensure WinDivert64.sys is present` — if
  the 4 required files aren't all present, or you didn't run as
  Administrator, or (once those are ruled out) WinDivert itself doesn't
  like something about this specific machine — see the main
  [`docs/README.txt`](../docs/README.txt) troubleshooting section; or
- the program actually starts and stays running — if everything above
  is in order and WinDivert loaded successfully.

Either way, if you see the feature-specific log lines called out in the
table above *before* that point, the feature itself is confirmed
working correctly — that's what these scripts are actually checking.

## A known quirk you might hit if you also test under Wine

If you're running these under Wine (Linux) rather than real Windows:
Wine's Service Control Manager is a known-incomplete simulation, not a
full implementation. You may see it report a service as
`START_PENDING` forever, or contradict itself between commands (e.g.
"already running" right after install, then "service has not been
started" when you try to stop it moments later). This is a Wine
limitation, not a bug in this program — the same service code was
separately verified to behave correctly via the equivalent interactive
code path (see the main README's Status section). On real Windows, `sc
query` should report state transitions accurately.
