param()

$USB_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
& "$USB_ROOT\command-core\runtime\windows.ps1" -USB_ROOT $USB_ROOT
exit $LASTEXITCODE
