param()

$USB_ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
$global:USB_ROOT = $USB_ROOT
$env:USB_ROOT = $USB_ROOT

. "$USB_ROOT\command-core\lib\ui_common.ps1"
. "$USB_ROOT\command-core\lib\setup_common.ps1"
Initialize-WarStickSetup
