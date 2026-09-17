param()

$USB_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$USB_ROOT\command-core\lib\ui_common.ps1"
Show-WarStickTankAnimation
& "$USB_ROOT\command-core\runtime\windows.ps1" -USB_ROOT $USB_ROOT
exit $LASTEXITCODE
