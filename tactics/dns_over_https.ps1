# NAME: DNS over HTTPS (DoH) Recon
# DESC: Query Cloudflare DoH API for authoritative A, AAAA, MX, TXT, NS records
# ARGS: true
param([string]$Target)

if ([string]::IsNullOrWhiteSpace($Target)) {
    Write-Host "Error: Target domain required (e.g. example.com)" -ForegroundColor Red
    exit 1
}

$domain = $Target -replace '^https?://', '' -replace '/.*$', '' -replace ':.*$', ''
Write-Host "[*] Querying Cloudflare DoH for: $domain`n" -ForegroundColor Cyan

foreach ($rtype in @("A", "AAAA", "MX", "TXT", "NS")) {
    Write-Host "--- [$rtype RECORDS] ---" -ForegroundColor Yellow
    try {
        $resp = Invoke-RestMethod -Uri "https://cloudflare-dns.com/dns-query?name=$domain&type=$rtype" -Headers @{ "accept" = "application/dns-json" } -TimeoutSec 5
        if ($resp.Answer) {
            foreach ($ans in $resp.Answer) {
                Write-Host "  $($ans.data)"
            }
        } else {
            Write-Host "  (None found)"
        }
    } catch {
        Write-Host "  Query failed: $($_.Exception.Message)"
    }
}
