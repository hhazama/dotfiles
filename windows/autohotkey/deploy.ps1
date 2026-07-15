# Deploy app-switch.ahk / moveVirtualDesktop.ahk to a Windows-local folder and
# register them to auto-start at logon. Re-run after editing to re-apply.
# (ASCII only on purpose: Windows PowerShell 5.1 reads BOM-less .ps1 as the
#  system codepage, so non-ASCII here would break parsing. Docs are in README.)
#
# Run from Windows PowerShell:
#   powershell -ExecutionPolicy Bypass -File "\\wsl.localhost\Ubuntu\data\repos\hhazama\dotfiles\windows\autohotkey\deploy.ps1"
#
# Copies to a Windows-local path because the \\wsl path may not resolve right
# after logon, so autostart is not pointed directly at it.

$ErrorActionPreference = 'Stop'

$src     = $PSScriptRoot
$dst     = Join-Path $env:LOCALAPPDATA 'autohotkey-scripts'
$startup = [Environment]::GetFolderPath('Startup')

$files   = @('app-switch.ahk', 'moveVirtualDesktop.ahk', 'VirtualDesktopAccessor.dll')
$scripts = @('app-switch.ahk', 'moveVirtualDesktop.ahk')

New-Item -ItemType Directory -Force -Path $dst | Out-Null

# 1) Stop our running scripts FIRST. They LoadLibrary the DLL, which locks it;
#    copying over a locked DLL fails, so release it before copying.
#    Only our two scripts are targeted (matched by command line).
Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" |
    Where-Object { $_.CommandLine -match 'app-switch|moveVirtualDesktop' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

# 2) Copy files. Retry the DLL in case its handle lingers just after exit.
foreach ($f in $files) {
    $from = Join-Path $src $f
    $to   = Join-Path $dst $f
    for ($i = 0; $i -lt 10; $i++) {
        try { Copy-Item -Force -Path $from -Destination $to; break }
        catch { if ($i -eq 9) { throw }; Start-Sleep -Milliseconds 300 }
    }
    Write-Host "copied : $f"
}

# 3) Create Startup shortcuts (target is the .ahk itself = same path as double-click)
$sh = New-Object -ComObject WScript.Shell
foreach ($s in $scripts) {
    $lnk = Join-Path $startup ([IO.Path]::GetFileNameWithoutExtension($s) + '.lnk')
    $sc  = $sh.CreateShortcut($lnk)
    $sc.TargetPath       = Join-Path $dst $s
    $sc.WorkingDirectory = $dst
    $sc.Save()
    Write-Host "startup: $lnk"
}

# 4) Launch the deployed copies now (no re-logon needed)
foreach ($s in $scripts) {
    Start-Process (Join-Path $dst $s)
    Write-Host "started: $s"
}

Write-Host ""
Write-Host "Done. Test: Alt+1..4 / Alt+0, Win+1..4 / Win+Shift+1..4 / Win+Ctrl+Shift+Left/Right"
