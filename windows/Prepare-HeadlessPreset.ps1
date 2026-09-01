[CmdletBinding()]
param(
    [string]$OutputFile = "not_logged_in_yet",
    [string]$RootMountPath
)
$ErrorActionPreference = "Stop"
if ($RootMountPath) { $OutputFile = Join-Path $RootMountPath "root\.not_logged_in_yet" }
$userName = Read-Host "Username [orangepi]"; if (-not $userName) { $userName = "orangepi" }
$rootPassword = Read-Host "Root password" -AsSecureString
$userPassword = Read-Host "User password" -AsSecureString
$wifiSsid = Read-Host "Wi-Fi SSID"
$wifiPassword = Read-Host "Wi-Fi password" -AsSecureString
function Unsecure([Security.SecureString]$Value) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}
$rootPlain = Unsecure $rootPassword; $userPlain = Unsecure $userPassword; $wifiPlain = Unsecure $wifiPassword
function Escape-ConfigValue([string]$Value) {
    return $Value.Replace('\', '\\').Replace('"', '\"').Replace('$', '\$').Replace('`', '\`')
}
$userName = Escape-ConfigValue $userName
$rootPlain = Escape-ConfigValue $rootPlain; $userPlain = Escape-ConfigValue $userPlain
$wifiSsid = Escape-ConfigValue $wifiSsid; $wifiPlain = Escape-ConfigValue $wifiPlain
$content = @"
PRESET_NET_CHANGE_DEFAULTS="1"
PRESET_NET_WIFI_ENABLED="1"
PRESET_NET_WIFI_SSID="$wifiSsid"
PRESET_NET_WIFI_KEY="$wifiPlain"
PRESET_NET_WIFI_COUNTRYCODE="US"
PRESET_CONNECT_WIRELESS="n"
PRESET_NET_USE_STATIC="0"
PRESET_ROOT_PASSWORD="$rootPlain"
PRESET_USER_NAME="$userName"
PRESET_USER_PASSWORD="$userPlain"
PRESET_DEFAULT_REALNAME="$userName"
PRESET_USER_SHELL="bash"
SET_LANG_BASED_ON_LOCATION="n"
PRESET_LOCALE="en_US.UTF-8"
PRESET_TIMEZONE="America/Los_Angeles"
"@
$parent = Split-Path -Parent $OutputFile
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
$fullOutput = [IO.Path]::GetFullPath($OutputFile)
[IO.File]::WriteAllText($fullOutput, $content)
Write-Host "Created $fullOutput. Copy it to /root/.not_logged_in_yet and delete it after first boot."
