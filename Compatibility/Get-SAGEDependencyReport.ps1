# SAGE Dependency Preflight 2.1
# Read-only checks only. Does not download, install, repair, or remove software.
Set-StrictMode -Version 2.0

function Get-SAGEDotNetDesktopVersions {
    [CmdletBinding()]
    param()
    $roots = @()
    if ($env:ProgramFiles) { $roots += (Join-Path $env:ProgramFiles 'dotnet\shared\Microsoft.WindowsDesktop.App') }
    $pf86 = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($pf86) { $roots += (Join-Path $pf86 'dotnet\shared\Microsoft.WindowsDesktop.App') }

    $versions = @()
    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root -PathType Container) {
            $versions += Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
                ForEach-Object { $_.Name }
        }
    }
    return @($versions | Sort-Object -Unique)
}

function Get-SAGEVCRuntimeState {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][ValidateSet('x64','ARM64')][string]$Architecture)
    $path = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\' + $Architecture
    try {
        $item = Get-ItemProperty -LiteralPath $path -ErrorAction Stop
        if ([int]$item.Installed -eq 1) {
            return [pscustomobject]@{ State='Present'; Version=[string]$item.Version }
        }
        return [pscustomobject]@{ State='Missing'; Version=$null }
    }
    catch {
        return [pscustomobject]@{ State='Unknown'; Version=$null }
    }
}

function Get-SAGEDependencyFacts {
    [CmdletBinding()]
    param()
    $frameworkRelease = $null
    try {
        $framework = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full' -Name Release -ErrorAction Stop
        $frameworkRelease = [int]$framework.Release
    } catch { }

    $appRuntime = @()
    try {
        if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) {
            $appRuntime = @(Get-AppxPackage -Name 'Microsoft.WindowsAppRuntime*' -ErrorAction SilentlyContinue |
                ForEach-Object { [pscustomobject]@{ Name=$_.Name; Version=[string]$_.Version; Architecture=[string]$_.Architecture } })
        }
    } catch { }

    $pwsh76 = $null
    try {
        $pwsh = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        if ($null -ne $pwsh) {
            $productVersion = [string](Get-Item -LiteralPath $pwsh.Source -ErrorAction Stop).VersionInfo.ProductVersion
            $pwsh76 = ($productVersion -match '^7\.6(\.|$)')
        } else { $pwsh76 = $false }
    } catch { }

    return [pscustomobject]@{
        DotNetDesktopVersions = @(Get-SAGEDotNetDesktopVersions)
        DotNetFrameworkRelease = $frameworkRelease
        WindowsAppRuntimePackages = @($appRuntime)
        VCRedistX64 = Get-SAGEVCRuntimeState -Architecture x64
        VCRedistARM64 = Get-SAGEVCRuntimeState -Architecture ARM64
        PowerShell76Available = $pwsh76
    }
}

function Get-SAGEDependencyReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][psobject]$CompatibilityReport,
        [Parameter()][psobject]$Facts
    )
    if ($null -eq $Facts) { $Facts = Get-SAGEDependencyFacts }

    $dotnet10 = @($Facts.DotNetDesktopVersions | Where-Object { [string]$_ -match '^10\.0\.' })
    $framework48 = $false
    if ($null -ne $Facts.DotNetFrameworkRelease) { $framework48 = ([int]$Facts.DotNetFrameworkRelease -ge 528040) }

    $checks = @()
    if ($CompatibilityReport.CompatibilityTier -eq 'LegacyCompatibility' -and $CompatibilityReport.OSFamily -eq 'Windows10') {
        $frameworkState = 'Unknown'
        if ($null -ne $Facts.DotNetFrameworkRelease) {
            if ($framework48) { $frameworkState = 'Present' } else { $frameworkState = 'Missing' }
        }
        $checks += [pscustomobject]@{
            Name='.NET Framework 4.8 or later'; State=$frameworkState
            RequiredFor='Windows 10 legacy WPF client'; DetectedVersion=[string]$Facts.DotNetFrameworkRelease
        }
    }

    if ($CompatibilityReport.OSFamily -eq 'Windows11' -and $CompatibilityReport.ModernWinUIClientEligible) {
        $dotnetState = 'Missing'
        if ($dotnet10.Count -gt 0) { $dotnetState = 'Present' }
        $checks += [pscustomobject]@{
            Name='.NET 10 Windows Desktop Runtime'; State=$dotnetState
            RequiredFor='Framework-dependent modern desktop client'; DetectedVersion=($dotnet10 -join ',')
        }
        $checks += [pscustomobject]@{
            Name='Windows App SDK runtime'; State='DeploymentModeDependent'
            RequiredFor='Unpackaged framework-dependent WinUI deployment'; DetectedVersion=(@($Facts.WindowsAppRuntimePackages | ForEach-Object { $_.Version }) -join ',')
        }
        $vc = $null
        if ($CompatibilityReport.Architecture -eq 'x64') { $vc = $Facts.VCRedistX64 }
        elseif ($CompatibilityReport.Architecture -eq 'ARM64') { $vc = $Facts.VCRedistARM64 }
        $vcState = 'Unknown'
        $vcVersion = $null
        if ($null -ne $vc) { $vcState = [string]$vc.State; $vcVersion = [string]$vc.Version }
        $checks += [pscustomobject]@{
            Name='Visual C++ 2015-2022 Redistributable'; State=$vcState
            RequiredFor='Unpackaged native desktop dependencies; confirm against publish mode'; DetectedVersion=$vcVersion
        }
    }

    $psState = 'Unknown'
    if ($null -ne $Facts.PowerShell76Available) {
        if ([bool]$Facts.PowerShell76Available) { $psState='Present' } else { $psState='NotPresent' }
    }
    $checks += [pscustomobject]@{
        Name='PowerShell 7.6'; State=$psState; RequiredFor='Optional modern automation engine'; DetectedVersion=$null
    }

    $missingRequired = @($checks | Where-Object { $_.RequiredFor -like 'Windows 10 legacy*' -and $_.State -eq 'Missing' })
    if ($CompatibilityReport.OSFamily -eq 'Windows11') {
        $missingRequired = @($checks | Where-Object { $_.Name -eq '.NET 10 Windows Desktop Runtime' -and $_.State -eq 'Missing' })
    }
    $overall = 'ReviewRequired'
    if ($missingRequired.Count -gt 0) { $overall = 'MissingRequiredDependency' }
    elseif ($CompatibilityReport.CompatibilityTier -eq 'Unsupported') { $overall = 'UnsupportedPlatform' }

    return [pscustomobject]@{
        SchemaVersion='2.1'; OverallState=$overall; Checks=$checks
        PerformsInstallation=$false; RequiresPackagingPolicyDecision=$true
        Notes=@(
            'Runtime presence does not establish Microsoft platform support.',
            'Windows App SDK and VC++ requirements depend on the actual MSIX, framework-dependent, or self-contained publish mode.',
            'PowerShell 7.6 is optional; Windows PowerShell 5.1 remains the administration compatibility baseline.'
        )
    }
}
