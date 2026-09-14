# NAME: External IP & Geolocation
# DESC: Fetch public IP, ISP organization, ASN, city, and country details
# ARGS: false

Write-Host "Querying ipinfo.io for host public route data..." -ForegroundColor Cyan
try {
    $data = Invoke-RestMethod -Uri "https://ipinfo.io/json" -Method Get -TimeoutSec 6
    $data | Format-List ip, hostname, city, region, country, loc, org, postal, timezone
} catch {
    curl.exe -s "https://ipinfo.io"
}
