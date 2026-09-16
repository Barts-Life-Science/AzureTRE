# =============================================================================
# IMPORTANT - READ BEFORE EDITING (humans and AI tools alike):
#
# This file is NOT run directly. Terraform renders it through the templatefile()
# function (see windowsvm.tf) BEFORE it is base64-encoded and injected as the VM
# custom_data. It is plain-text template substitution and ignores quoting, so
# the rule below applies EVERYWHERE, including inside here-strings.
#
# A token of the form  dollar-sign + {NAME}  is a Terraform TEMPLATE variable,
# substituted at deploy time. ONLY names present in the templatefile() map in
# windowsvm.tf are valid. Current keys:
#     nexus_proxy_url, SharedStorageAccess, StorageAccountName,
#     StorageAccountKey1, StorageAccountKey2, StorageAccountFileHost,
#     FileShareName, CondaConfig
#
# Any OTHER dollar-brace (or percent-brace) token makes Terraform FAIL the
# render with "vars map does not contain key ...". You therefore CANNOT invent
# arbitrary variables using brace syntax - not even in a comment like this one.
#
# CAUTION - PowerShell's own variable syntax uses the same brace form, so it
# COLLIDES with Terraform:
#   * Bare PowerShell vars with NO braces - $CondaRc, $RProfilePath, $env:PATH -
#     are safe; Terraform ignores them and PowerShell expands them on the VM.
#   * A PowerShell variable that needs braces at RUNTIME must double the dollar
#     sign to escape it (two dollars, then the brace); the rendered script then
#     contains a single dollar plus brace token that PowerShell evaluates.
#   * To pass a NEW deploy-time value, add it to the templatefile() map in
#     windowsvm.tf first, then reference it here.
#
# ASCII ONLY - no Unicode anywhere in this file (encoding-sensitive when run via
# CustomScriptExtension).
# =============================================================================
Remove-Item -LiteralPath "C:\AzureData" -Force -Recurse
$ErrorActionPreference = "Stop"

if( $SharedStorageAccess -eq 1 -and $StorageAccountKey1 -match "/")
{
  $Command = "net use z: \\${StorageAccountFileHost}\${FileShareName} /u:AZURE\${StorageAccountName} ${StorageAccountKey2}"
  $Command | Out-File  "C:\ProgramData\Start Menu\Programs\StartUp\attach_storage.cmd" -encoding ascii
} else
{
  $Command = "net use z: \\${StorageAccountFileHost}\${FileShareName} /u:AZURE\${StorageAccountName} ${StorageAccountKey1}"
  $Command | Out-File  "C:\ProgramData\Start Menu\Programs\StartUp\attach_storage.cmd" -encoding ascii
}

$PipConfigFolderPath = "C:\ProgramData\pip\"
If(!(Test-Path $PipConfigFolderPath))
{
  New-Item -ItemType Directory -Force -Path $PipConfigFolderPath
}

$PipConfigFilePath = $PipConfigFolderPath + "pip.ini"

$ConfigBody = @"
[global]
index = ${nexus_proxy_url}/repository/pypi/pypi
index-url = ${nexus_proxy_url}/repository/pypi/simple
trusted-host = ${nexus_proxy_url}
"@

# We need to write the ini file in UTF8 (No BOM) as pip won't understand Powershell's default encoding (unicode)
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
[System.IO.File]::WriteAllLines($PipConfigFilePath, $ConfigBody, $Utf8NoBomEncoding)

### Anaconda Config
if( ${CondaConfig} -eq 1 )
{
  $CondaRc = @"
channels:
  - ${nexus_proxy_url}/repository/conda-repo/main/
  - ${nexus_proxy_url}/repository/conda-mirror/main/
custom_channels:
  conda-forge: ${nexus_proxy_url}/repository/conda-mirror/
  bioconda: ${nexus_proxy_url}/repository/conda-mirror/
  defaults: ${nexus_proxy_url}/repository/conda-mirror/
"@
  # Validated: the 2026-04 Windows images ship Miniconda at C:\Miniconda3, so its base
  # .condarc lives here (conda info --base == C:\Miniconda3).
  $CondaRc | Out-File -Encoding Ascii -FilePath "C:\Miniconda3\.condarc"
}

# Docker proxy config
$DaemonConfig = @"
{
"registry-mirrors": ["${nexus_proxy_url}:8083"]
}
"@
$DaemonConfig | Out-File -Encoding Ascii ( New-Item -Path $env:ProgramData\docker\config\daemon.json -Force )

# R config - write to a fixed path and point R at it via R_PROFILE so the config
# is version-independent and survives R upgrades.
$RProfileDir = "C:\ProgramData\R"
$RProfilePath = "$RProfileDir\Rprofile.site"
if (-not (Test-Path $RProfileDir)) {
    New-Item -Path $RProfileDir -ItemType Directory -Force | Out-Null
}
$RConfig = @"
local({
  options( repos = c( "Nexus" = "${nexus_proxy_url}/repository/r-proxy/" ) )

  options(
    download.file.method = "curl",
    download.file.extra  = "--ssl-no-revoke"
  )
})
"@
$RConfig | Out-File -Encoding Ascii -FilePath $RProfilePath
[System.Environment]::SetEnvironmentVariable("R_PROFILE", $RProfilePath, [System.EnvironmentVariableTarget]::Machine)
[System.Environment]::SetEnvironmentVariable("NEXUS_PROXY_URL", "${nexus_proxy_url}", [System.EnvironmentVariableTarget]::Machine)

#
# TODO: This is probably obsolete
# The new 2025-03 images have a conda config that doesn't get cleaned up. Do that here.
# Turn off error handling since I don't know how this will work in older images. For
# the same reason, put it at the end of the script.
# $ErrorActionPreference = "Continue"
# conda config --remove channels https://repo.anaconda.com/pkgs/main --system
# conda config --remove channels https://repo.anaconda.com/pkgs/r --system
# conda config --remove channels https://repo.anaconda.com/pkgs/msys2 --system
