# Vista / Server 2008 compatibility — an honest assessment

This isn't a claim that Extended ProxyBridge works on Windows Vista or
Server 2008. It's a look at how hard it would probably be, and how
confident anyone should be in the result, written down before actually
attempting it — done because the question came up, not because there's
a concrete plan to support these OSes right now.

## Short version

- Our own code (this fork's C source) doesn't appear to add any barrier
  beyond what WinDivert itself already requires. Every Windows API this
  fork uses that's newer than "ancient" — `SRWLOCK` (SRWLock family),
  `GetTickCount64`, `QueryFullProcessImageName`, and the `TokenElevation`
  token info class used for the admin check — were all introduced in
  Windows Vista, not later. None of them are Windows-7-specific.
- The real uncertainty is entirely in the WinDivert driver, which this
  project doesn't control and can't verify without either a definitive
  statement from its maintainer or an actual Vista/Server 2008 machine
  to test on.
- **Verdict: plausible, not verified, moderate risk concentrated in one
  place (the driver, not the application code).**

## What the research turned up

WinDivert 2.x's documentation has stated different minimum versions at
different points in time, all on the same site (reqrypt.org):

- The archived WinDivert 1.0 docs explicitly list "Windows Vista,
  Windows Server 2008, and Windows 7."
- Every WinDivert 2.x doc page found states "Windows 7, Windows 8 and
  Windows 10" (this project uses WinDivert 2.2.2).
- The current windivert.com / newest reqrypt.org pages have moved even
  further, to "Windows 10, Windows 11, and Windows Server."

Nowhere is there an explicit "Vista is broken" or "Vista was dropped in
2.x" statement — but the officially claimed floor has clearly been
creeping upward release over release, which reads more like "we stopped
testing/mentioning old versions as they aged out" than "we hit a wall
and had to drop support." Those are different situations with different
risk profiles, and there's no way to tell which one it actually is
without either asking the maintainer directly or testing.

The underlying technology WinDivert is built on, the Windows Filtering
Platform (WFP), was introduced in Vista and is confirmed (via
WinDivert's own FAQ) to be the reason XP/2003 aren't supported at all —
so there's no fundamental architectural reason a WFP-based driver
*couldn't* run on Vista. But WinDivert 2.x's driver is also described as
using WDF ("a modern WDF/WFP driver implementation"), and WDF itself has
had multiple versions with their own minimum-OS requirements over the
years — it's entirely possible a specific WDF version WinDivert 2.x
settled on has a Windows 7 floor even though WFP itself doesn't. This
project has no way to determine that without either the driver's build
configuration (not published) or a real test.

## What it would actually take, if this becomes a real goal later

1. **Get an actual Vista or Server 2008 machine or VM.** There's no
   substitute for this — Wine can't help here (no real kernel driver
   support, same limitation documented in the main README for WinDivert
   testing in general), and there's no other way to know if the driver
   loads at all.
2. **Try the existing x86 build first**, since 32-bit Vista was far more
   common than 64-bit Vista in practice, and Server 2008 (non-R2) was
   also commonly 32-bit.
3. **If WinDivert itself fails to load** (`WinDivertOpen` erroring out,
   the driver refusing to install, etc.) — that's the real blocker, and
   it's outside this project's control. The options at that point would
   be: stay on WinDivert 2.2.2 and accept no Vista support, or
   investigate whether an older WinDivert 1.x driver (a genuinely
   different, older architecture) could be swapped in instead — which
   would be a substantially larger undertaking, likely requiring
   reworking how this project talks to the driver, not just a recompile.
4. **If WinDivert loads fine**, the remaining work is small: recompile
   this fork's own code with `_WIN32_WINNT=0x0600` (Vista) instead of
   `0x0601` (Windows 7) currently used, and go through the normal
   scenarios in `docs/README.txt` one by one on the real machine —
   rules, failover, the service lifecycle, and (most importantly, given
   it's the least-tested part even on modern Windows) DNS interception.

## How stable would it likely be, if it does turn out to work

Genuinely hard to say with any confidence, and it would be dishonest to
project a number here. What can be said:

- Vista and Server 2008 are old, essentially unmaintained (both are
  long past Microsoft's extended support windows), so any problem
  encountered there gets zero help from upstream Windows updates ever
  fixing it — whatever bugs exist on that platform stay bugs forever.
- The DNS interception path (already the least-verified part of this
  fork even on modern Windows, per the main README's Status section) is
  the piece most likely to behave differently on an old TCP/IP stack —
  older Windows versions had different default behavior around things
  like non-blocking socket edge cases, which the DNS worker thread relies
  on.
- Nothing else in this fork's own additions (failover, service support,
  rename-friendly builds) touches anything OS-version-sensitive beyond
  what's listed above, so if the driver loads and DNS interception is
  simply not used (rules without `DnsResolution` behave exactly as
  upstream ProxyBridge always did), there's no obvious reason those
  specific features would be less stable on Vista than on Windows 7.

In short: worth a try if the need ever comes up, but budget real time
for it, don't promise it to end users until it's actually been run on
a real Vista/Server 2008 machine, and expect the DNS feature specifically
to need the closest attention if support is pursued.
