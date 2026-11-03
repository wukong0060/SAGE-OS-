# SAGE Security Posture 2.1
# Read-only observation. Never changes security policy or disables protections.
Set-StrictMode -Version 2.0

function Get-SAGESecurityFacts {
    [CmdletBinding()]
    param()
    $uac = $null
    try {
        $v = Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction Stop
        $uac = ([int]$v.EnableLUA -eq 1)
    } catch { }

    $memoryIntegrity = $null
    try {
        $v = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name Enabled -ErrorAction Stop
        $memoryIntegrity = ([int]$v.Enabled -eq 1)
    } catch { }

    $vbsStatus = $null
    $hvciRunning = $null
    try {
        $dg = Get-CimInstance -Namespace 'root\Microsoft\Windows\DeviceGuard' -ClassName Win32_DeviceGuard -ErrorAction Stop
        $vbsStatus = [int]$dg.VirtualizationBasedSecurityStatus
        $hvciRunning = (@($dg.SecurityServicesRunning) -contains 2)
    } catch { }

    $secureBoot = $null
    try { $secureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { }

    $defenderRealtime = $null
    try {
        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            $defenderRealtime = [bool]$mp.RealTimeProtectionEnabled
        }
    } catch { }

    $smbSigningRequired = $null
    try {
        if (Get-Command Get-SmbClientConfiguration -ErrorAction SilentlyContinue) {
            $smb = Get-SmbClientConfiguration -ErrorAction Stop
            $smbSigningRequired = [bool]$smb.RequireSecuritySignature
        }
    } catch { }

    $appControl = $null
    try {
        $policyPath = Join-Path $env:windir 'System32\CodeIntegrity\CiPolicies\Active'
        $sipolicy = Join-Path $env:windir 'System32\CodeIntegrity\SIPolicy.p7b'
        $appControl = ((Test-Path -LiteralPath $sipolicy) -or
            ((Test-Path -LiteralPath $policyPath) -and (@(Get-ChildItem -LiteralPath $policyPath -File -ErrorAction SilentlyContinue).Count -gt 0)))
    } catch { }

    $smartAppControl = $null
    try {
        $policy = Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy' -Name VerifiedAndReputablePolicyState -ErrorAction Stop
        switch ([int]$policy.VerifiedAndReputablePolicyState) {
            0 { $smartAppControl='Off' }
            1 { $smartAppControl='Enforced' }
            2 { $smartAppControl='Evaluation' }
            default { $smartAppControl='Unknown' }
        }
    } catch { }

    return [pscustomobject]@{
        UACEnabled=$uac
        SecureBootEnabled=$secureBoot
        MemoryIntegrityConfigured=$memoryIntegrity
        VBSStatus=$vbsStatus
        HVCIRunning=$hvciRunning
        DefenderRealtimeProtectionEnabled=$defenderRealtime
        SMBClientSigningRequired=$smbSigningRequired
        AppControlPolicyDetected=$appControl
        SmartAppControlState=$smartAppControl
    }
}

function ConvertTo-SAGESecurityState {
    [CmdletBinding()]
    param([Parameter()][object]$Value)
    if ($null -eq $Value) { return 'Unknown' }
    if ($Value -is [bool]) { if ($Value) { return 'Enabled' } else { return 'Disabled' } }
    return [string]$Value
}

function Get-SAGESecurityPosture {
    [CmdletBinding()]
    param([Parameter()][psobject]$Facts)
    if ($null -eq $Facts) { $Facts = Get-SAGESecurityFacts }

    $vbsState = 'Unknown'
    if ($null -ne $Facts.VBSStatus) {
        switch ([int]$Facts.VBSStatus) {
            0 { $vbsState='Disabled' }
            1 { $vbsState='EnabledNotRunning' }
            2 { $vbsState='EnabledAndRunning' }
            default { $vbsState='Unknown' }
        }
    }

    $items = @(
        [pscustomobject]@{ Name='User Account Control'; State=(ConvertTo-SAGESecurityState $Facts.UACEnabled); Detail='UAC is observed, never modified by SAGE.' }
        [pscustomobject]@{ Name='Secure Boot'; State=(ConvertTo-SAGESecurityState $Facts.SecureBootEnabled); Detail='Firmware capability and state may require manual firmware/update verification.' }
        [pscustomobject]@{ Name='Memory Integrity'; State=(ConvertTo-SAGESecurityState $Facts.MemoryIntegrityConfigured); Detail='Configured state; check HVCI runtime state separately.' }
        [pscustomobject]@{ Name='VBS'; State=$vbsState; Detail='0=disabled, 1=enabled but not running, 2=enabled and running; Unknown means query unavailable.' }
        [pscustomobject]@{ Name='HVCI running'; State=(ConvertTo-SAGESecurityState $Facts.HVCIRunning); Detail='Runtime state, not inferred from registry configuration.' }
        [pscustomobject]@{ Name='Defender real-time protection'; State=(ConvertTo-SAGESecurityState $Facts.DefenderRealtimeProtectionEnabled); Detail='Unknown may mean Defender cmdlets are unavailable or access was denied.' }
        [pscustomobject]@{ Name='SMB client signing required'; State=(ConvertTo-SAGESecurityState $Facts.SMBClientSigningRequired); Detail='Reports the local client setting; server policy and negotiated session still matter.' }
        [pscustomobject]@{ Name='App Control policy detected'; State=(ConvertTo-SAGESecurityState $Facts.AppControlPolicyDetected); Detail='Presence check only; not a complete policy evaluation.' }
        [pscustomobject]@{ Name='Smart App Control'; State=(ConvertTo-SAGESecurityState $Facts.SmartAppControlState); Detail='Off, Enforced, Evaluation or Unknown.' }
    )
    return [pscustomobject]@{
        SchemaVersion='2.1'; Items=$items; ReadOnlyAssessment=$true
        AutoRemediationAllowed=$false
        SafetyRule='SAGE must preserve platform security controls and must never disable them as an optimization.'
    }
}
