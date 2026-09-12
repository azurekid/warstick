# NAME: Shodan InternetDB Host Recon
# DESC: Query open ports, vulnerabilities (CVEs), and tags for target IP
# ARGS: true
param([string]$Target)

if ([string]::IsNullOrWhiteSpace($Target)) {
    Write-Host "Error: Target IP required (e.g. 1.1.1.1)" -ForegroundColor Red
    exit 1
}

$clean = $Target -replace '^https?://', '' -replace '/.*$', '' -replace ':.*$', ''
Write-Host "[*] Querying Shodan InternetDB for: $clean`n" -ForegroundColor Cyan

try {
    $resp = Invoke-RestMethod -Uri "https://internetdb.shodan.io/$clean" -TimeoutSec 6
    $resp | Format-List ip, hostnames, ports, cpes, vulns, tags
} catch {
    curl.exe -s "https://internetdb.shodan.io/$clean"
}
