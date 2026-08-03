# Pre-built binaries

`ProxyBridge_CLI.exe` and `ProxyBridgeCore.dll` — built via
`x86_64-w64-mingw32-gcc` from the exact source in `Windows/src` and
`Windows/cli` in this repo (see the main README for the build command,
if you'd rather build them yourself and verify).

**You still need two more files before this runs**, which aren't ours to
redistribute — download them from the official WinDivert release:

https://github.com/basil00/WinDivert/releases/tag/v2.2.2

Grab `WinDivert.dll` and `WinDivert64.sys` from the `x64/` folder inside
that zip, and put them in this same folder next to the two files above.
All four files need to be together for the program to run.

See the main [README.md](../README.md) for what's tested and what isn't
yet — in particular, real WinDivert packet interception (including the
new DNS interception) has **not** been verified on real Windows yet.
