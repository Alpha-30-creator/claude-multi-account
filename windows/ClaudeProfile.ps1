<#
  Run Claude Desktop with a separate profile (own login, chats, settings).

  One-time setup - creates "Claude Work" shortcuts on the Desktop and Start menu:
      powershell -ExecutionPolicy Bypass -File ClaudeProfile.ps1 -Install -Name Work

  The shortcut then runs:   ClaudeProfile.ps1 -Name Work
  Optional, only if browser sign-in (Google/SSO) lands in the wrong window:
      ClaudeProfile.ps1 -Name Work -SignIn
#>
param(
  [string]$Name = "Work",
  [switch]$Install,
  [switch]$SignIn
)
$ErrorActionPreference = "Stop"

$Root       = Join-Path $env:LOCALAPPDATA "ClaudeProfiles"
$ProfileDir = Join-Path $env:APPDATA "Claude-$Name"
New-Item -ItemType Directory -Force -Path $Root, $ProfileDir | Out-Null

function Get-ClaudeExe {
  # Classic installer: the stub passes arguments through and survives updates.
  $classic = Join-Path $env:LOCALAPPDATA "AnthropicClaude\claude.exe"
  if (Test-Path $classic) { return $classic }

  # Store/MSIX install: Windows won't launch the exe from WindowsApps with custom
  # arguments, so keep a private copy and refresh it whenever Claude updates.
  $pkg = Get-AppxPackage -Name "*Claude*" | Where-Object { $_.Publisher -like "*Anthropic*" } |
         Sort-Object Version -Descending | Select-Object -First 1
  if (-not $pkg) { throw "Claude Desktop is not installed." }

  $src = Get-ChildItem -Path $pkg.InstallLocation -Filter "claude.exe" -Recurse -ErrorAction SilentlyContinue |
         Select-Object -First 1
  if (-not $src) { throw "claude.exe not found in $($pkg.InstallLocation)" }

  $copyDir = Join-Path $Root "app"
  $stamp   = Join-Path $copyDir ".version"
  $current = if (Test-Path $stamp) { Get-Content $stamp } else { "" }
  if ($current -ne $pkg.Version.ToString()) {
    $running = Get-Process -Name claude -ErrorAction SilentlyContinue |
               Where-Object { $_.Path -like "$copyDir*" }
    if ($running) {
      # Can't replace files in use; keep using the old copy until all profiles close.
      if (Test-Path (Join-Path $copyDir $src.Name)) { return (Join-Path $copyDir $src.Name) }
    }
    robocopy $src.DirectoryName $copyDir /MIR /NFL /NDL /NJH /NJS /NP /XF ".version" | Out-Null
    Set-Content -Path $stamp -Value $pkg.Version.ToString()
  }
  return (Join-Path $copyDir $src.Name)
}

if ($Install) {
  $self  = $PSCommandPath
  $dest  = Join-Path $Root "ClaudeProfile.ps1"
  if ($self -ne $dest) { Copy-Item $self $dest -Force }
  $exe   = Get-ClaudeExe
  $shell = New-Object -ComObject WScript.Shell
  foreach ($dir in @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("Programs"))) {
    $lnk = $shell.CreateShortcut((Join-Path $dir "Claude $Name.lnk"))
    $lnk.TargetPath       = "powershell.exe"
    $lnk.Arguments        = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$dest`" -Name `"$Name`""
    $lnk.IconLocation     = "$exe,0"
    $lnk.WorkingDirectory = $Root
    $lnk.Save()
  }
  Write-Host "Created 'Claude $Name' shortcuts (Desktop + Start menu)."
  Write-Host "Profile folder: $ProfileDir"
  Write-Host "First time: close your other Claude, open 'Claude $Name', sign in."
  exit 0
}

$exe = Get-ClaudeExe

if ($SignIn) {
  # Point claude:// links at this profile so a browser sign-in returns here.
  # Your normal Claude re-registers itself the next time it starts.
  $key = "HKCU:\Software\Classes\claude"
  New-Item -Path "$key\shell\open\command" -Force | Out-Null
  Set-ItemProperty -Path $key -Name "(Default)" -Value "URL:claude"
  Set-ItemProperty -Path $key -Name "URL Protocol" -Value ""
  Set-ItemProperty -Path "$key\shell\open\command" -Name "(Default)" `
    -Value "`"$exe`" --user-data-dir=`"$ProfileDir`" `"%1`""
}

# Claude's own single-instance lock is per data folder, so launching an
# already-open profile just focuses its window.
Start-Process -FilePath $exe -ArgumentList "--user-data-dir=`"$ProfileDir`""
