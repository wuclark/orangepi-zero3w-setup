[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$GpuVpuRoot,
    [Parameter(Mandatory=$true)][string]$NpuRoot,
    [Parameter(Mandatory=$true)][string]$OutputDirectory,
    [string]$WslDistribution = ""
)
$ErrorActionPreference = "Stop"
if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw "wsl.exe is required; mount or unpack the source image inside WSL first."
}
$wslArgs = @()
if ($WslDistribution) { $wslArgs += @("-d", $WslDistribution) }
$wslGpuVpuRoot = (& wsl.exe @wslArgs -- wslpath -a $GpuVpuRoot).Trim()
$wslNpuRoot = (& wsl.exe @wslArgs -- wslpath -a $NpuRoot).Trim()
$wslOutput = (& wsl.exe @wslArgs -- wslpath -a $OutputDirectory).Trim()
if ($LASTEXITCODE -ne 0) { throw "Could not translate paths for WSL." }
$scriptPath = (Resolve-Path "$PSScriptRoot/../scripts/extract-vendor-userspace.sh").Path
$wslScript = (& wsl.exe @wslArgs -- wslpath -a $scriptPath).Trim()
& wsl.exe @wslArgs -- bash $wslScript --gpu-vpu-root $wslGpuVpuRoot --npu-root $wslNpuRoot --output-dir $wslOutput
if ($LASTEXITCODE -ne 0) { throw "Userspace extraction failed." }
Write-Host "Userspace archives created in $OutputDirectory"
