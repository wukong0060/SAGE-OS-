# SAGE Compatibility Engine 2.1 - dependency and security preflight

This milestone adds two read-only report modules to the Compatibility Engine 2.0
feature branch.

## Dependency preflight
- Detects .NET Desktop shared runtimes, .NET Framework 4.8 release key,
  Windows App Runtime packages visible to the current user, Visual C++ runtime
  registry state, and optional PowerShell 7.6.
- Checks .NET Framework 4.8 for the Windows 10 legacy WPF lane and .NET 10
  Windows Desktop Runtime for the Windows 11 modern WinUI lane.
- Deliberately reports Windows App SDK and Visual C++ deployment as
  packaging-mode-dependent. SAGE must first declare MSIX/framework-dependent
  versus unpackaged/self-contained deployment before calling either missing.
- Never downloads or installs dependencies.

## Security posture
- Reports UAC, Secure Boot, Memory Integrity, VBS/HVCI, Defender real-time
  protection, SMB client signing, App Control policy presence and Smart App
  Control state where readable.
- Distinguishes Disabled from Unknown; unavailable APIs or insufficient access
  are not treated as evidence that a protection is disabled.
- Never changes security settings, firmware state, Defender configuration,
  driver policy, SMB settings or application-control policy.

## Test
Run both synthetic suites in Windows PowerShell 5.1:
- Tests/CompatibilityEngine.Tests.ps1
- Tests/DependencySecurity.Tests.ps1

These validate report logic with injected facts. They do not replace native
Windows VM, hardware, package-installation or policy-enforcement testing.
