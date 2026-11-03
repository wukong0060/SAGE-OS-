# SAGE Dependency Preflight 2.1
# Read-only checks only. Does not download, install, repair, or remove software.
Set-StrictMode -Version 2.0

function Get-SAGEDotNetRuntimeVersions {
    [CmdletBinding()]
    param()
    $root = $null
    if ($env:ProgramFiles) { $root = Join-Path $env:ProgramFiles 'dotnet\shared' }
    $core = @()
    $desktop = @()
    if ($root -and (Test-Path -LiteralPath (Join-Path $root 'Microsoft.NETCore.App') -PathType Container)) {
        $core = @(Get-ChildItem -LiteralPath (Join-Path $root 'Microsoft.NETCore.App') -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    }
    if ($root -and (Test-Path -LiteralPath (Join-Path $root 'Microsoft.WindowsDesktop.App') -PathType Container)) {
        $desktop = @(Get-ChildItem -LiteralPath (Join-Path $root 'Microsoft.WindowsDesktop.App') -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
    }
    return [pscustomobject]@{ Core=@($core | Sort-Object -Unique); Desktop=@($desktop | Sort-Object -Unique) }
}

function Get-SAGEVCRuntimeState {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][ValidateSet('x64','ARM64')][string]$Architecture)
    $path = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\' + $Architecture
    try {
        $item = Get-ItemProperty -LiteralPath $path -ErrorAction Stop
        if ([int]$item.Installed -eq 1) { return [pscustomobject]@{ State='Present'; Version=[string]$item.Version } }
        return [pscustomobject]@{ State='Missing'; Version=$null }
    } catch { return [pscustomobject]@{ State='Unknown'; Version=$null } }
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

    $dotnet = Get-SAGEDotNetRuntimeVersions
    return [pscustomobject]@{
        DotNetCoreVersions = @($dotnet.Core)
        DotNetDesktopVersions = @($dotnet.Desktop)
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
        [Parameter()][psobject]$Facts,
        [Parameter()][ValidateSet('Unknown','FrameworkDependent','SelfContained')][string]$RuntimeDeploymentMode='Unknown',
        [Parameter()][ValidateSet('Unknown','MSIX','Unpackaged')][string]$PackageType='Unknown'
    )
    if ($null -eq $Facts) { $Facts = Get-SAGEDependencyFacts }

    $dotnetCore10 = @($Facts.DotNetCoreVersions | Where-Object { [string]$_ -match '^10\.0\.' })
    $dotnetDesktop10 = @($Facts.DotNetDesktopVersions | Where-Object { [string]$_ -match '^10\.0\.' })
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
        $coreState = 'NotEvaluatedUntilPublishModeDeclared'
        if ($dotnetCore10.Count -gt 0) { $coreState = 'Present' }
        elseif ($RuntimeDeploymentMode -eq 'FrameworkDependent') { $coreState = 'Missing' }
        elseif ($RuntimeDeploymentMode -eq 'SelfContained') { $coreState = 'BundledNotRequired' }
        $checks += [pscustomobject]@{
            Name='.NET 10 base runtime (Microsoft.NETCore.App)'; State=$coreState
            RequiredFor='Framework-dependent modern .NET client'; DetectedVersion=($dotnetCore10 -join ',')
        }
        $desktopState = 'NotDetected'
        if ($dotnetDesktop10.Count -gt 0) { $desktopState = 'Present' }
        $checks += [pscustomobject]@{
            Name='.NET 10 Windows Desktop runtime'; State=$desktopState
            RequiredFor='Optional; needed only by WPF/WinForms components'; DetectedVersion=($dotnetDesktop10 -join ',')
        }
        $appSdkState = 'NotEvaluatedUntilPackageTypeDeclared'
        if ($PackageType -eq 'MSIX') { $appSdkState = 'ManifestDependencyMustBeDeclared' }
        elseif ($PackageType -eq 'Unpackaged' -and $RuntimeDeploymentMode -eq 'FrameworkDependent') {
            if (@($Facts.WindowsAppRuntimePackages).Count -gt 0) { $appSdkState = 'SharedRuntimePackageObserved' }
            else { $appSdkState = 'SharedRuntimePackageNotObserved' }
        }
        elseif ($PackageType -eq 'Unpackaged' -and $RuntimeDeploymentMode -eq 'SelfContained') { $appSdkState = 'SelfContainedAppSdkPolicyRequired' }
        $checks += [pscustomobject]@{
            Name='Windows App SDK runtime'; State=$appSdkState
            RequiredFor=($PackageType + ' deployment; verify framework package dependency or self-contained runtime policy')
            DetectedVersion=(@($Facts.WindowsAppRuntimePackages | ForEach-Object { $_.Version }) -join ',')
        }
        $vc = $null
        if ($CompatibilityReport.Architecture -eq 'x64') { $vc = $Facts.VCRedistX64 }
        elseif ($CompatibilityReport.Architecture -eq 'ARM64') { $vc = $Facts.VCRedistARM64 }
        $vcState = 'Unknown'; $vcVersion = $null
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
    if ($CompatibilityReport.OSFamily -eq 'Windows11' -and $RuntimeDeploymentMode -eq 'FrameworkDependent') {
        $missingRequired = @($checks | Where-Object { $_.Name -eq '.NET 10 base runtime (Microsoft.NETCore.App)' -and $_.State -eq 'Missing' })
    }
    $overall = 'ReviewRequired'
    if ($missingRequired.Count -gt 0) { $overall = 'MissingRequiredDependency' }
    elseif ($CompatibilityReport.CompatibilityTier -eq 'Unsupported') { $overall = 'UnsupportedPlatform' }

    return [pscustomobject]@{
        SchemaVersion='2.1'; OverallState=$overall; Checks=$checks
        PerformsInstallation=$false; RequiresPackagingPolicyDecision=($RuntimeDeploymentMode -eq 'Unknown' -or $PackageType -eq 'Unknown')
        RuntimeDeploymentMode=$RuntimeDeploymentMode; PackageType=$PackageType
        Notes=@(
            'Runtime presence does not establish Microsoft platform support.',
            'Windows App SDK and Visual C++ requirements depend on MSIX versus unpackaged deployment and framework-dependent versus self-contained publishing.',
            'The modern WinUI application requires the .NET base runtime when framework-dependent; Windows Desktop runtime is only needed by WPF/WinForms components.',
            'PowerShell 7.6 is optional; Windows PowerShell 5.1 remains the administration compatibility baseline.'
        )
    }
}
