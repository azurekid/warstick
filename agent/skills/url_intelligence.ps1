# NAME: URL Intelligence & Header Parser
# DESC: Parse URL structure, analyze redirect chains, and inspect security headers
# ARGS: true
param([string]$Target)

if ([string]::IsNullOrWhiteSpace($Target)) {
    Write-Host "Error: Target URL required (e.g. https://example.com)" -ForegroundColor Red
    exit 1
}

if ($Target -notmatch '^https?://') {
    $Target = "https://$Target"
}

Write-Host "[*] Analyzing Target URL: $Target" -ForegroundColor Cyan

try {
    $uri = [System.Uri]$Target
    Write-Host "`n--- [URL STRUCTURE] ---" -ForegroundColor Magenta
    Write-Host "  Scheme   : $($uri.Scheme)"
    Write-Host "  Host     : $($uri.Host)"
    Write-Host "  Port     : $($uri.Port)"
    Write-Host "  Path/URI : $($uri.PathAndQuery)"

    Write-Host "`n--- [DNS RESOLUTION] ---" -ForegroundColor Magenta
    try {
        [System.Net.Dns]::GetHostAddresses($uri.Host) | ForEach-Object {
            Write-Host "  IP Address : $($_.IPAddressToString)"
        }
    } catch { }

    Write-Host "`n--- [HTTP HEADERS & SECURITY POLICIES] ---" -ForegroundColor Magenta
    $req = [System.Net.HttpWebRequest]::Create($Target)
    $req.Method = "HEAD"
    $req.AllowAutoRedirect = $true
    $resp = $req.GetResponse()
    foreach ($k in $resp.Headers.AllKeys) {
        if ($k -match '^(Server|Location|Strict-Transport-Security|Content-Security-Policy|X-Frame-Options|X-Content-Type-Options|Set-Cookie|Access-Control-Allow-Origin)') {
            Write-Host "  $k: $($resp.Headers[$k])"
        }
    }
    $resp.Close()
} catch {
    Write-Host "HTTP Query Exception: $($_.Exception.Message)" -ForegroundColor Yellow
}
