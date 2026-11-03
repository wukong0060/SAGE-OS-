# Dependency-free Windows PowerShell 5.1 regression tests.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\Compatibility\Get-SAGECompatibility.ps1')
function Assert-Equal {param([object]$Actual,[object]$Expected,[string]$Name) if($Actual -ne $Expected){throw ("FAIL: {0}; expected [{1}], got [{2}]" -f $Name,$Expected,$Actual)}}
function New-Facts {
 param([string]$ProductName,[string]$DisplayVersion,[string]$Build,[string]$Architecture='x64',[int]$ProductType=1)
 [pscustomobject]@{ProductName=$ProductName;DisplayVersion=$DisplayVersion;CurrentBuildNumber=$Build;UBR=0;EditionID='Professional';InstallationType='Client';Architecture=$Architecture;ProductType=$ProductType;PowerShellVersion='5.1.0';PowerShellEdition='Desktop';PowerShell7Available=$false;DotNet10RuntimePresent=$false}
}
$a=Get-SAGECompatibilityReport (New-Facts 'Windows 10 Pro' '22H2' '19045')
Assert-Equal $a.CompatibilityTier 'LegacyCompatibility' 'Win10 22H2 x64'
Assert-Equal $a.LegacyClientEligible $true 'Win10 legacy client'
Assert-Equal $a.ModernWinUIClientEligible $false 'Win10 modern UI gated'
Assert-Equal $a.ServicingStatusIsVerified $false 'servicing not guessed'
$b=Get-SAGECompatibilityReport (New-Facts 'Windows 11 Pro' '25H2' '26200')
Assert-Equal $b.CompatibilityTier 'ModernCandidate' 'Win11 candidate'
Assert-Equal $b.ModernWinUIClientEligible $true 'Win11 modern UI'
Assert-Equal $b.PreferredTestTarget $true 'preferred test target'
$c=Get-SAGECompatibilityReport (New-Facts 'Windows 10 Pro' '22H2' '19044')
Assert-Equal $c.CompatibilityTier 'Unsupported' 'old Win10 build'
$d=Get-SAGECompatibilityReport (New-Facts 'Windows 10 Pro' '22H2' '19045' 'ARM64')
Assert-Equal $d.CompatibilityTier 'Unsupported' 'Win10 ARM64 excluded'
$e=Get-SAGECompatibilityReport (New-Facts 'Windows Server' '2025' '26100' 'x64' 3)
Assert-Equal $e.CompatibilityTier 'Unsupported' 'Server excluded'
$f=Get-SAGECompatibilityReport (New-Facts 'Unknown Windows' 'unknown' '0')
Assert-Equal $f.CompatibilityTier 'Unsupported' 'unknown fails closed'
$serverFallback=Get-SAGECompatibilityReport (New-Facts 'Windows Server 2025' '2025' '26100' 'x64' 0)
Assert-Equal $serverFallback.CompatibilityTier 'Unsupported' 'Server identity fallback'
$unknownArch=Get-SAGECompatibilityReport (New-Facts 'Windows 11 Pro' '25H2' '26200' 'Unknown')
Assert-Equal $unknownArch.CompatibilityTier 'Unsupported' 'Unknown architecture fails closed'
$arm11=Get-SAGECompatibilityReport (New-Facts 'Windows 11 Pro' '25H2' '26200' 'ARM64')
Assert-Equal $arm11.ModernWinUIClientEligible $true 'Windows 11 ARM64 candidate'
Write-Output 'SAGE Compatibility Engine 2.0 tests passed: 14 assertions.'
