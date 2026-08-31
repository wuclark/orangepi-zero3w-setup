<#
.SYNOPSIS
Copies an extracted PowerVR vendor filesystem from Windows to the optional GPU module.

.DESCRIPTION
Run this script in Windows PowerShell 5.1 or PowerShell 7. It validates the
important files, creates a tar archive so the usr/... hierarchy is preserved,
copies it with Windows OpenSSH, extracts it into vendor-root on the Orange Pi,
verifies the remote result, and removes both temporary archives.

The Orange Pi must already be reachable over SSH. The repository should be
extracted or cloned at /home/orangepi/orangepi-zero3w-setup unless -RemoteRepoPath
specifies another location.

.EXAMPLE
Set-ExecutionPolicy -Scope Process Bypass
.\windows\Copy-PvrVendorRoot.ps1 `
  -SourcePath "C:\Users\William\Downloads\pvr-stage" `
  -BoardHost "192.168.7.123"

.EXAMPLE
.\windows\Copy-PvrVendorRoot.ps1 `
  -SourcePath "D:\A733\pvr-stage" `
  -BoardHost "orangepizero3w.local" `
  -SshUser "orangepi" `
  -RemoteRepoPath "/home/orangepi/zero3w-pvr-forge"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9._-]+$')]
    [string]$BoardHost,

    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_-]*$')]
    [string]$SshUser = 'orangepi',

    [ValidatePattern('^/[A-Za-z0-9._/-]+$')]
    [string]$RemoteRepoPath = '/home/orangepi/orangepi-zero3w-setup',

    [ValidateRange(1, 65535)]
    [int]$SshPort = 22
)

$ErrorActionPreference = 'Stop'
$SourcePath = (Resolve-Path -LiteralPath $SourcePath).Path

foreach ($Command in @('tar.exe', 'scp.exe', 'ssh.exe')) {
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "Required Windows command not found: $Command. Install the Windows OpenSSH Client optional feature."
    }
}

function Assert-VendorMatch {
    param([Parameter(Mandatory = $true)][string]$RelativePattern)

    $Parent = Split-Path $RelativePattern -Parent
    $Leaf = Split-Path $RelativePattern -Leaf
    $SearchRoot = Join-Path $SourcePath $Parent
    if (-not (Test-Path -LiteralPath $SearchRoot -PathType Container)) {
        throw "Missing vendor directory: $Parent"
    }
    if (-not (Get-ChildItem -LiteralPath $SearchRoot -Filter $Leaf -Force -ErrorAction SilentlyContinue)) {
        throw "Missing vendor file: $RelativePattern"
    }
}

Write-Host 'Validating the extracted PowerVR filesystem...'
@(
    'usr\lib\libVK_IMG.so*',
    'usr\lib\libsrv_um.so*',
    'usr\lib\libGLESv2_PVR_MESA.so*',
    'usr\local\lib\libpvr_mesa_wsi.so*',
    'usr\local\lib\dri\pvr_dri.so'
) | ForEach-Object { Assert-VendorMatch -RelativePattern $_ }

$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$ArchiveName = "zero3w-pvr-vendor-$Stamp.tar"
$LocalArchive = Join-Path ([System.IO.Path]::GetTempPath()) $ArchiveName
$RemoteArchive = "/tmp/$ArchiveName"
$Destination = "${SshUser}@${BoardHost}:$RemoteArchive"

try {
    Write-Host "Creating temporary archive: $LocalArchive"
    & tar.exe -C $SourcePath -cf $LocalArchive .
    if ($LASTEXITCODE -ne 0) { throw "tar.exe failed with exit code $LASTEXITCODE" }

    Write-Host "Testing SSH connection to $SshUser@$BoardHost..."
    & ssh.exe -p $SshPort "$SshUser@$BoardHost" 'true'
    if ($LASTEXITCODE -ne 0) { throw "SSH connection failed with exit code $LASTEXITCODE" }

    Write-Host 'Uploading vendor archive...'
    & scp.exe -P $SshPort $LocalArchive $Destination
    if ($LASTEXITCODE -ne 0) { throw "SCP upload failed with exit code $LASTEXITCODE" }

    # Both paths are constrained by ValidatePattern, so the remote command does
    # not accept shell metacharacters from parameters.
    $RemoteVendorRoot = "$RemoteRepoPath/vendor-root"
    $RemoteCommand = "set -eu; test -f '$RemoteRepoPath/install.sh'; mkdir -p '$RemoteVendorRoot'; tar -xf '$RemoteArchive' -C '$RemoteVendorRoot'; rm -f '$RemoteArchive'; ls '$RemoteVendorRoot/usr/lib/'libVK_IMG.so* >/dev/null"

    Write-Host "Extracting into $RemoteVendorRoot..."
    & ssh.exe -p $SshPort "$SshUser@$BoardHost" $RemoteCommand
    if ($LASTEXITCODE -ne 0) { throw "Remote extraction or verification failed with exit code $LASTEXITCODE" }

    Write-Host ''
    Write-Host 'Transfer complete.' -ForegroundColor Green
    Write-Host 'Next, SSH into the board and run:'
    Write-Host "  cd $RemoteRepoPath"
    Write-Host '  ./armbian-startup.sh'
}
finally {
    if (Test-Path -LiteralPath $LocalArchive) {
        Remove-Item -LiteralPath $LocalArchive -Force
    }
}
