# SAGE Compatibility Engine 2.0 - read-only; Windows PowerShell 5.1 compatible.
Set-StrictMode -Version 2.0
function Get-SAGERegistryValue {
 [CmdletBinding()] param([Parameter(Mandatory=$true)][string]$Path,[Parameter(Mandatory=$true)][string]$Name)
 try { $item=Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop; return $item.$Name } catch { return $null }
}
function Test-SAGEDotNet10DesktopRuntime {
 [CmdletBinding()] param()
 $roots=@()
 if($env:ProgramFiles){$roots+=(Join-Path $env:ProgramFiles 'dotnet\shared\Microsoft.WindowsDesktop.App')}
 $pf86=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
 if($pf86){$roots+=(Join-Path $pf86 'dotnet\shared\Microsoft.WindowsDesktop.App')}
 foreach($root in $roots){
  if(Test-Path -LiteralPath $root -PathType Container){
   $runtime=Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '^10\.0\.'} | Select-Object -First 1
   if($null -ne $runtime){return $true}
  }
 }
 return $false
}
function Get-SAGECompatibilityFacts {
 [CmdletBinding()] param()
 $p='HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'; $os=$null
 try{$os=Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop}catch{try{$os=Get-WmiObject -Class Win32_OperatingSystem -ErrorAction Stop}catch{}}
 $arch='Unknown'
 if($null -ne $os -and $os.OSArchitecture){if([string]$os.OSArchitecture -match 'ARM'){$arch='ARM64'}elseif([string]$os.OSArchitecture -match '64'){$arch='x64'}elseif([string]$os.OSArchitecture -match '32'){$arch='x86'}}
 elseif([Environment]::Is64BitOperatingSystem){$arch='x64'}else{$arch='x86'}
 $ps7=$false; try{$ps7=($null -ne (Get-Command pwsh.exe -ErrorAction SilentlyContinue))}catch{}
 [pscustomobject]@{
  ProductName=[string](Get-SAGERegistryValue $p 'ProductName'); DisplayVersion=[string](Get-SAGERegistryValue $p 'DisplayVersion')
  CurrentBuildNumber=[string](Get-SAGERegistryValue $p 'CurrentBuildNumber'); UBR=Get-SAGERegistryValue $p 'UBR'
  EditionID=[string](Get-SAGERegistryValue $p 'EditionID'); InstallationType=[string](Get-SAGERegistryValue $p 'InstallationType')
  Architecture=$arch; ProductType=if($null -ne $os){[int]$os.ProductType}else{0}
  PowerShellVersion=[string]$PSVersionTable.PSVersion; PowerShellEdition=[string]$PSVersionTable.PSEdition
  PowerShell7Available=[bool]$ps7; DotNet10DesktopRuntimePresent=[bool](Test-SAGEDotNet10DesktopRuntime)
 }
}
function Get-SAGECompatibilityReport {
 [CmdletBinding()] param([Parameter()][psobject]$Facts)
 if($null -eq $Facts){$Facts=Get-SAGECompatibilityFacts}
 $build=0; if(-not [int]::TryParse([string]$Facts.CurrentBuildNumber,[ref]$build)){$build=0}
 $name=[string]$Facts.ProductName; $version=[string]$Facts.DisplayVersion; $arch=[string]$Facts.Architecture
 $server=([int]$Facts.ProductType -ne 1 -and [int]$Facts.ProductType -ne 0)
 $family='Unknown'; if($name -match 'Windows 11' -or $build -ge 22000){$family='Windows11'}elseif($name -match 'Windows 10'){$family='Windows10'}
 $tier='Unsupported'; $reason='The detected operating system is outside the declared SAGE compatibility baseline.'
 $legacy=$false; $modern=$false; $custom=$false; $preferred=$false
 if($server){$reason='Windows Server is not covered by the SAGE desktop compatibility contract.'}
 elseif($family -eq 'Windows10' -and $version -eq '22H2' -and $build -ge 19045 -and $arch -eq 'x64'){$tier='LegacyCompatibility';$reason='Windows 10 22H2 x64 is eligible for the legacy client and legacy feature set only.';$legacy=$true}
 elseif($family -eq 'Windows11' -and $build -ge 22000 -and ($arch -eq 'x64' -or $arch -eq 'ARM64')){$tier='ModernCandidate';$reason='Windows 11 meets the technical baseline; edition, servicing and feature-specific validation remain required.';$legacy=$true;$modern=$true;$custom=$true;$preferred=($version -eq '25H2' -or $version -eq '26H2')}
 elseif($family -eq 'Windows10'){$reason='Windows 10 must be 22H2 build 19045 or later on x64.'}
 elseif($family -eq 'Windows11'){$reason='Windows 11 build 22000 or later on x64 or ARM64 is required.'}
 $servicing='NotEvaluated'; if($family -eq 'Windows10'){$servicing='CheckEditionAndESUOrLTSC'}elseif($family -eq 'Windows11'){$servicing='CheckEditionAndCurrentServicingRelease'}
 [pscustomobject]@{
  SchemaVersion='2.0';EngineVersion='2.0.0';ProductName=$name;DisplayVersion=$version;Build=$build;UBR=$Facts.UBR
  Edition=[string]$Facts.EditionID;InstallationType=[string]$Facts.InstallationType;Architecture=$arch;OSFamily=$family;IsServer=$server
  CompatibilityTier=$tier;CompatibilityReason=$reason;ServicingStatus=$servicing;ServicingStatusIsVerified=$false
  LegacyClientEligible=$legacy;ModernWinUIClientEligible=$modern;Windows11CustomizationEligible=$custom;PreferredTestTarget=$preferred
  PowerShellVersion=[string]$Facts.PowerShellVersion;PowerShellEdition=[string]$Facts.PowerShellEdition
  PowerShell7Available=[bool]$Facts.PowerShell7Available;DotNet10DesktopRuntimePresent=[bool]$Facts.DotNet10DesktopRuntimePresent
  RequiresNativeValidation=$true;ReadOnlyAssessment=$true
 }
}
