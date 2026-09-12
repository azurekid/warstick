@echo off
setlocal
set "USB_ROOT=%~dp0"
set "USB_ROOT=%USB_ROOT:~0,-1%"

:: Launch centralized PowerShell interface with execution bypass
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%USB_ROOT%\run-windows.ps1"

