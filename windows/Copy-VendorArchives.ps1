[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$SourceDirectory,
    [Parameter(Mandatory=$true)][string]$BoardHost,
    [string]$SshUser = "orangepi",
    [int]$SshPort = 22,
    [string]$RemoteRepoPath = "/home/orangepi/orangepi-zero3w-setup"
)
$ErrorActionPreference = "Stop"
$pvr = Join-Path $SourceDirectory "pvr-userspace.tar.gz"
$vpu = Join-Path $SourceDirectory "vpu-userspace.tar.gz"
if (-not (Test-Path -LiteralPath $pvr -PathType Leaf)) { throw "Missing $pvr" }
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) { throw "OpenSSH ssh is not installed." }
if (-not (Get-Command scp -ErrorAction SilentlyContinue)) { throw "OpenSSH scp is not installed." }

$destination = "${SshUser}@${BoardHost}"
& ssh -p $SshPort $destination "mkdir -p '$RemoteRepoPath/vendor-files'"
if ($LASTEXITCODE -ne 0) { throw "SSH connection or remote mkdir failed." }
& scp -P $SshPort -- $pvr "${destination}:$RemoteRepoPath/vendor-files/pvr-userspace.tar.gz"
if ($LASTEXITCODE -ne 0) { throw "PVR archive upload failed." }
if (Test-Path -LiteralPath $vpu -PathType Leaf) {
    & scp -P $SshPort -- $vpu "${destination}:$RemoteRepoPath/vendor-files/vpu-userspace.tar.gz"
    if ($LASTEXITCODE -ne 0) { throw "VPU archive upload failed." }
}
Write-Host "Archives copied unchanged. On the board run: cd $RemoteRepoPath && ./armbian-startup.sh"
