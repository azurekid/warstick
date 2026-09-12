# NAME: Reverse IP & Shared Host Finder
# DESC: Find other domains and virtual hosts co-located on target IP address
# ARGS: true
param([string]$Target)

if ([string]::IsNullOrWhiteSpace($Target)) {
    Write-Host "Error: Target IP or domain required (e.g. 1.1.1.1 or example.com)" -ForegroundColor Red
    exit 1
}

$clean = $Target -replace '^https?://', '' -replace '/.*$', '' -replace ':.*$', ''
Write-Host "[*] Querying HackerTarget Reverse IP for: $clean`n" -ForegroundColor Cyan

try {
    $resp = Invoke-RestMethod -Uri "https://api.hackertarget.com/reverseiplookup/?q=$clean" -TimeoutSec 6
    Write-Host $resp
} catch {
    curl.exe -s "https://api.hackertarget.com/reverseiplookup/?q=$clean"
}
