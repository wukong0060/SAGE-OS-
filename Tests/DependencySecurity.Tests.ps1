# Synthetic tests for SAGE dependency and security preflight.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\Compatibility\Get-SAGECompatibility.ps1')
. (Join-Path $PSScriptRoot '..\Compatibility\Get-SAGEDependencyReport.ps1')
. (Join-Path $PSScriptRoot '..\Security\Get-SAGESecurityPosture.ps1')
function Assert-Equal { param([object]$Actual,[object]$Expected,[string]$Name) if($Actual -ne $Expected){throw ("FAIL: {0}; expected [{1}], got [{2}]" -f $Name,$Expected,$Actual)} }

$compat10=[pscustomobject]@{CompatibilityTier='LegacyCompatibility';OSFamily='Windows10';Architecture='x64'}
$deps10=[pscustomobject]@{DotNetCoreVersions=@();DotNetDesktopVersions=@();DotNetFrameworkRelease=528040;WindowsAppRuntimePackages=@();VCRedistX64=[pscustomobject]@{State='Present';Version='14.x'};VCRedistARM64=[pscustomobject]@{State='Unknown';Version=$null};PowerShell76Available=$false}
$r10=Get-SAGEDependencyReport -CompatibilityReport $compat10 -Facts $deps10
Assert-Equal $r10.OverallState 'ReviewRequired' 'Win10 framework runtime is present'
Assert-Equal $r10.PerformsInstallation $false 'Dependency check never installs'

$deps10.DotNetFrameworkRelease=0
$r10missing=Get-SAGEDependencyReport -CompatibilityReport $compat10 -Facts $deps10
Assert-Equal $r10missing.OverallState 'MissingRequiredDependency' 'Missing .NET Framework 4.8 detected'

$compat11=[pscustomobject]@{CompatibilityTier='ModernCandidate';OSFamily='Windows11';Architecture='x64';ModernWinUIClientEligible=$true}
$deps11=[pscustomobject]@{DotNetCoreVersions=@('10.0.14');DotNetDesktopVersions=@();WindowsAppRuntimePackages=@();VCRedistX64=[pscustomobject]@{State='Present';Version='14.x'};VCRedistARM64=[pscustomobject]@{State='Unknown';Version=$null};PowerShell76Available=$true}
$r11=Get-SAGEDependencyReport -CompatibilityReport $compat11 -Facts $deps11 -RuntimeDeploymentMode FrameworkDependent -PackageType Unpackaged
Assert-Equal $r11.OverallState 'ReviewRequired' 'Win11 .NET 10 present'
Assert-Equal $r11.RequiresPackagingPolicyDecision $false 'Packaging modes are explicit'
Assert-Equal $r11.Checks[3].State 'SharedRuntimePackageNotObserved' 'Unpackaged framework-dependent App SDK package check'

$deps11.DotNetCoreVersions=@()
$r11missing=Get-SAGEDependencyReport -CompatibilityReport $compat11 -Facts $deps11 -RuntimeDeploymentMode FrameworkDependent -PackageType Unpackaged
Assert-Equal $r11missing.OverallState 'MissingRequiredDependency' 'Missing .NET 10 detected'

$deps11.DotNetCoreVersions=@()
$r11unknownMode=Get-SAGEDependencyReport -CompatibilityReport $compat11 -Facts $deps11
Assert-Equal $r11unknownMode.OverallState 'ReviewRequired' 'Unknown publish mode does not produce a false missing-runtime failure'
Assert-Equal $r11unknownMode.Checks[0].State 'NotEvaluatedUntilPublishModeDeclared' 'Runtime requirement is deferred until publish mode is known'

$r11selfContained=Get-SAGEDependencyReport -CompatibilityReport $compat11 -Facts $deps11 -RuntimeDeploymentMode SelfContained -PackageType MSIX
Assert-Equal $r11selfContained.OverallState 'ReviewRequired' 'Self-contained app does not require machine .NET runtime'
Assert-Equal $r11selfContained.Checks[0].State 'BundledNotRequired' 'Self-contained runtime is bundled'

$secFacts=[pscustomobject]@{UACEnabled=$true;SecureBootEnabled=$true;MemoryIntegrityConfigured=$true;VBSStatus=2;HVCIRunning=$true;DefenderRealtimeProtectionEnabled=$true;SMBClientSigningRequired=$true;AppControlPolicyDetected=$false;SmartAppControlState='Enforced'}
$sec=Get-SAGESecurityPosture -Facts $secFacts
Assert-Equal $sec.ReadOnlyAssessment $true 'Security posture is read-only'
Assert-Equal $sec.AutoRemediationAllowed $false 'No security auto-remediation'
Assert-Equal $sec.Items[0].State 'Enabled' 'UAC state normalized'
Assert-Equal $sec.Items[8].State 'Enforced' 'Smart App Control state preserved'

$unknownFacts=[pscustomobject]@{UACEnabled=$null;SecureBootEnabled=$null;MemoryIntegrityConfigured=$null;VBSStatus='Unknown';HVCIRunning=$null;DefenderRealtimeProtectionEnabled=$null;SMBClientSigningRequired=$null;AppControlPolicyDetected=$null;SmartAppControlState=$null}
$unknown=Get-SAGESecurityPosture -Facts $unknownFacts
Assert-Equal $unknown.Items[0].State 'Unknown' 'Unavailable is not treated as disabled'
Assert-Equal $unknown.Items[1].State 'Unknown' 'Secure Boot query failure remains unknown'
Assert-Equal $unknown.Items[3].State 'Unknown' 'Nonnumeric VBS status remains unknown'

Write-Output 'SAGE dependency and security preflight tests passed: 19 assertions.'
