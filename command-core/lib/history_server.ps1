param(
    [Parameter(Mandatory = $true)]
    [string]$HistoryFile
)

$ErrorActionPreference = 'Stop'
$hostAddress = [System.Net.IPAddress]::Parse('127.0.0.1')
$port = 9932
$maxBodyBytes = 5MB
$utf8 = New-Object System.Text.UTF8Encoding($false)
$listener = [System.Net.Sockets.TcpListener]::new($hostAddress, $port)

function ConvertTo-HistoryMessages($Value) {
    $messages = @()
    foreach ($item in @($Value)) {
        if ($null -eq $item -or $item.role -notin @('user', 'assistant') -or $item.content -isnot [string]) {
            throw 'Each message needs a valid role and string content.'
        }
        $messages += [ordered]@{ role = $item.role; content = $item.content }
    }
    return ,$messages
}

function Get-WarModeValue($Payload) {
    if ($Payload.PSObject.Properties.Name -notcontains 'warMode' -or $null -eq $Payload.warMode) { return $false }
    if ($Payload.warMode -isnot [bool]) { throw 'warMode must be a boolean.' }
    return $Payload.warMode
}

function Read-HttpLine($Stream) {
    $bytes = New-Object System.Collections.Generic.List[byte]
    while ($true) {
        $value = $Stream.ReadByte()
        if ($value -lt 0) { break }
        if ($value -eq 10) { break }
        if ($value -ne 13) { $bytes.Add([byte]$value) }
    }
    return [System.Text.Encoding]::ASCII.GetString($bytes.ToArray())
}

function Send-JsonResponse($Stream, [int]$StatusCode, $Payload) {
    $reason = switch ($StatusCode) {
        200 { 'OK' }
        204 { 'No Content' }
        400 { 'Bad Request' }
        404 { 'Not Found' }
        default { 'Internal Server Error' }
    }
    $body = if ($StatusCode -eq 204) { [byte[]]@() } else {
        $utf8.GetBytes(($Payload | ConvertTo-Json -Depth 5 -Compress))
    }
    $headers = "HTTP/1.1 $StatusCode $reason`r`n" +
        "Content-Type: application/json; charset=utf-8`r`n" +
        "Content-Length: $($body.Length)`r`n" +
        "Access-Control-Allow-Origin: http://127.0.0.1:9931`r`n" +
        "Access-Control-Allow-Methods: GET, PUT, DELETE, OPTIONS`r`n" +
        "Access-Control-Allow-Headers: Content-Type`r`n" +
        "Cache-Control: no-store`r`n" +
        "Connection: close`r`n`r`n"
    $headerBytes = $utf8.GetBytes($headers)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($body.Length -gt 0) { $Stream.Write($body, 0, $body.Length) }
    $Stream.Flush()
}

function Save-HistoryState($Messages, [bool]$WarMode) {
    $parent = Split-Path -Parent $HistoryFile
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    $temporaryFile = Join-Path $parent ("chat_history.{0}.tmp" -f [guid]::NewGuid().ToString('N'))
    try {
        $json = @{ messages = @($Messages); warMode = $WarMode } | ConvertTo-Json -Depth 5
        [System.IO.File]::WriteAllText($temporaryFile, $json + [Environment]::NewLine, $utf8)
        Move-Item -Path $temporaryFile -Destination $HistoryFile -Force
    } finally {
        Remove-Item $temporaryFile -Force -ErrorAction SilentlyContinue
    }
}

$listener.Start()
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $stream = $client.GetStream()
            $requestLine = Read-HttpLine $stream
            if ([string]::IsNullOrWhiteSpace($requestLine)) { continue }

            $requestParts = $requestLine.Split(' ')
            $method = $requestParts[0]
            $path = $requestParts[1]
            $contentLength = 0
            while ($true) {
                $header = Read-HttpLine $stream
                if ([string]::IsNullOrEmpty($header)) { break }
                if ($header -match '^Content-Length:\s*(\d+)$') { $contentLength = [int]$matches[1] }
            }

            if ($method -eq 'OPTIONS') {
                Send-JsonResponse $stream 204 @{}
                continue
            }
            if ($path -ne '/history') {
                Send-JsonResponse $stream 404 @{ error = 'not found' }
                continue
            }

            try {
                switch ($method) {
                    'GET' {
                        if (Test-Path $HistoryFile) {
                            $payload = Get-Content $HistoryFile -Raw -Encoding UTF8 | ConvertFrom-Json
                            $messages = ConvertTo-HistoryMessages $payload.messages
                            $warMode = Get-WarModeValue $payload
                        } else {
                            $messages = @()
                            $warMode = $false
                        }
                        Send-JsonResponse $stream 200 @{ messages = @($messages); warMode = $warMode }
                    }
                    'PUT' {
                        if ($contentLength -le 0 -or $contentLength -gt $maxBodyBytes) { throw 'Invalid request size.' }
                        $buffer = New-Object byte[] $contentLength
                        $readCount = 0
                        while ($readCount -lt $contentLength) {
                            $count = $stream.Read($buffer, $readCount, $contentLength - $readCount)
                            if ($count -le 0) { break }
                            $readCount += $count
                        }
                        if ($readCount -ne $contentLength) { throw 'Incomplete request body.' }
                        $payload = $utf8.GetString($buffer) | ConvertFrom-Json
                        $messages = ConvertTo-HistoryMessages $payload.messages
                        $warMode = Get-WarModeValue $payload
                        Save-HistoryState $messages $warMode
                        Send-JsonResponse $stream 200 @{ messages = @($messages); warMode = $warMode }
                    }
                    'DELETE' {
                        Remove-Item $HistoryFile -Force -ErrorAction SilentlyContinue
                        Send-JsonResponse $stream 200 @{ messages = @(); warMode = $false }
                    }
                    default { Send-JsonResponse $stream 404 @{ error = 'not found' } }
                }
            } catch {
                Send-JsonResponse $stream 400 @{ error = $_.Exception.Message }
            }
        } finally {
            $client.Dispose()
        }
    }
} finally {
    $listener.Stop()
}
