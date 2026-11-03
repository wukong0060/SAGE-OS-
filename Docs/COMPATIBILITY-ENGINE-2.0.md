# SAGE Compatibility Engine 2.0

Read-only compatibility contract for SAGE Core. Windows PowerShell 5.1 is the
administration baseline; PowerShell 7 is optional and detected, never assumed.

## Declared technical lanes
- Windows 10 22H2 build 19045+ x64: legacy compatibility lane.
- Windows 11 build 22000+ x64/ARM64: modern candidate lane.
- Windows Server, Windows 10 ARM64, unknown builds and unsupported releases fail closed.

## Safety and servicing
Compatibility is not a Microsoft servicing guarantee and is not production
certification. ServicingStatusIsVerified is always false. Windows 10 servicing
must be checked against edition and ESU/LTSC enrollment; Windows 11 servicing
must be checked against edition and current servicing release. Never infer
security support from a successful launch.

The module is read-only: it does not modify registry values, services, drivers,
security settings, files or Windows servicing configuration. It reports the
presence of the .NET 10 Windows Desktop shared runtime but does not certify
Windows 10 Home/Pro as a Microsoft-supported .NET 10 platform.

LegacyClientEligible, ModernWinUIClientEligible and
Windows11CustomizationEligible are UI/feature gates only. Each operation
still requires its own capability checks, preview, approval and rollback rules.
RequiresNativeValidation remains true until the exact edition/build,
architecture and dependency combination passes native Windows CI and VM tests.

Do not depend on wmic.exe; use CIM/WMI APIs. PowerShell 7.6 is optional.
Windows App SDK and .NET runtime installation remains the installer's responsibility.

## Test
Run under Windows PowerShell 5.1:
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Tests\CompatibilityEngine.Tests.ps1
Tests use synthetic facts and do not require elevation or alter the host.
