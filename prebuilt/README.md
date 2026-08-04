# Pre-built binaries

Both architectures are built from the exact same source in `Windows/src`
and `Windows/cli` in this repo.

- **`x64/`** — 64-bit build (`x86_64-w64-mingw32-gcc`). Use this on a
  64-bit Windows install, which is almost certainly what you have unless
  you know otherwise.
- **`x86/`** — 32-bit build (`i686-w64-mingw32-gcc`). For 32-bit Windows,
  or to run a 32-bit process on 64-bit Windows if you specifically need
  that.

Both were tested to actually load and run correctly under Wine (32-bit
under a dedicated `WINEARCH=win32` prefix, since a normal 64-bit Wine
prefix can't run 32-bit binaries without one) — including the failover
health-check logic against real sockets, not just "it compiled".

## You still need WinDivert's own files

Not ours to redistribute — download them from the official release:

https://github.com/basil00/WinDivert/releases/tag/v2.2.2

- For `x64/`: grab `WinDivert.dll` and `WinDivert64.sys` from the `x64/`
  folder in that zip.
- For `x86/`: grab `WinDivert.dll` **and both** `WinDivert32.sys` **and**
  `WinDivert64.sys` from the `x86/` folder in that zip. Yes, both .sys
  files — a 32-bit process needs the 32-bit driver on 32-bit Windows,
  but still needs the 64-bit driver if it's running on 64-bit Windows
  under WOW64 (a kernel driver always matches the OS's own bitness, not
  the process's). WinDivert's own DLL picks the right one automatically
  at runtime, you just need both present.

Put the matching WinDivert files in the same folder as
`ProxyBridge_CLI.exe`/`ProxyBridgeCore.dll` for whichever architecture
you're using — all files together, one architecture per folder, don't
mix x64 and x86 files in the same folder.

See the main [README.md](../README.md) for what's tested and what
isn't yet — in particular, real WinDivert packet interception
(including the new DNS interception) has **not** been verified on real
Windows yet, for either architecture.
