param(
    [Parameter(Mandatory = $true)][string]$SdBinary,
    [Parameter(Mandatory = $true)][string]$ModelsDirectory,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$hostAddress = [System.Net.IPAddress]::Parse('127.0.0.1')
$port = 9933
$maxBodyBytes = 64KB
$utf8 = New-Object System.Text.UTF8Encoding($false)
$listener = [System.Net.Sockets.TcpListener]::new($hostAddress, $port)

if (-not (Test-Path -LiteralPath $SdBinary -PathType Leaf)) { throw "Image-generation binary not found: $SdBinary" }
if (-not (Test-Path -LiteralPath $ModelsDirectory -PathType Container)) { throw "Image model directory not found: $ModelsDirectory" }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$models = @{}
$defaultModel = $null

function Update-ImageModels {
    $script:models = @{}
    $zImageDirectory = Join-Path $ModelsDirectory 'z-image-turbo'
    $zImageVae = Join-Path $zImageDirectory 'ae.safetensors'
    $zImageLlm = Join-Path $zImageDirectory 'Qwen3-4B-Instruct-2507-Q4_K_M.gguf'
    if ((Test-Path $zImageVae) -and (Test-Path $zImageLlm)) {
        Get-ChildItem -LiteralPath $zImageDirectory -Filter 'z_image_turbo-*.gguf' -File -ErrorAction SilentlyContinue | ForEach-Object {
            $script:models["z-image-turbo/$($_.Name)"] = @{
                Label = "Z-Image Turbo / $($_.Name)"
                Arguments = @('--diffusion-model', $_.FullName, '--vae', $zImageVae, '--llm', $zImageLlm)
                Steps = 8
            }
        }
    }

    if ($script:models.Count -eq 0) { throw "No complete image model bundles found below $ModelsDirectory" }
    $script:defaultModel = @($script:models.Keys | Sort-Object { if ($_ -like 'z-image-turbo/*') { 0 } else { 1 } }, { $_ })[0]
}

Update-ImageModels

function Read-HttpLine($Stream) {
    $bytes = New-Object System.Collections.Generic.List[byte]
    while ($true) {
        $value = $Stream.ReadByte()
        if ($value -lt 0 -or $value -eq 10) { break }
        if ($value -ne 13) { $bytes.Add([byte]$value) }
    }
    return [System.Text.Encoding]::ASCII.GetString($bytes.ToArray())
}

function Send-Response($Stream, [int]$StatusCode, [string]$ContentType, [byte[]]$Body) {
    $reason = switch ($StatusCode) {
        200 { 'OK' }
        204 { 'No Content' }
        400 { 'Bad Request' }
        404 { 'Not Found' }
        default { 'Internal Server Error' }
    }
    $headers = "HTTP/1.1 $StatusCode $reason`r`n" +
        "Content-Type: $ContentType`r`n" +
        "Content-Length: $($Body.Length)`r`n" +
        "Access-Control-Allow-Origin: http://127.0.0.1:9931`r`n" +
        "Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n" +
        "Access-Control-Allow-Headers: Content-Type`r`n" +
        "Cache-Control: no-store`r`n" +
        "Connection: close`r`n`r`n"
    $headerBytes = $utf8.GetBytes($headers)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($Body.Length -gt 0) { $Stream.Write($Body, 0, $Body.Length) }
    $Stream.Flush()
}

function Send-JsonResponse($Stream, [int]$StatusCode, $Payload) {
    $body = if ($StatusCode -eq 204) { [byte[]]@() } else {
        $utf8.GetBytes(($Payload | ConvertTo-Json -Depth 5 -Compress))
    }
    Send-Response $Stream $StatusCode 'application/json; charset=utf-8' $body
}

function Get-BoundedInteger($Value, [int]$Default, [int]$Minimum, [int]$Maximum, [string]$Name) {
    if ($null -eq $Value) { return $Default }
    $parsed = 0
    if (-not [int]::TryParse([string]$Value, [ref]$parsed) -or $parsed -lt $Minimum -or $parsed -gt $Maximum) {
        throw "$Name must be an integer between $Minimum and $Maximum."
    }
    return $parsed
}

function Invoke-ImageGeneration($Payload) {
    Update-ImageModels
    if ($Payload.prompt -isnot [string] -or [string]::IsNullOrWhiteSpace($Payload.prompt) -or $utf8.GetByteCount($Payload.prompt) -gt 8KB) {
        throw 'Prompt must be a non-empty string no larger than 8 KB.'
    }

    $width = Get-BoundedInteger $Payload.width 1024 256 4096 'width'
    $height = Get-BoundedInteger $Payload.height 1024 256 4096 'height'
    $model = if ([string]::IsNullOrWhiteSpace($Payload.model)) { $defaultModel } else { [string]$Payload.model }
    if (-not $models.ContainsKey($model)) { throw 'Unknown image model.' }
    $steps = Get-BoundedInteger $Payload.steps $models[$model].Steps 1 50 'steps'
    if ($width % 64 -ne 0 -or $height % 64 -ne 0) { throw 'Width and height must be multiples of 64.' }

    $seed = if ($null -eq $Payload.seed) { Get-Random -Minimum 0 -Maximum 2147483647 } else {
        Get-BoundedInteger $Payload.seed 0 0 2147483647 'seed'
    }
    $filename = 'z-image-{0}-{1}.png' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $seed
    $outputPath = Join-Path $OutputDirectory $filename
    $arguments = @(
        $models[$model].Arguments
        '--prompt', $Payload.prompt,
        '--cfg-scale', '1.0',
        '--steps', [string]$steps,
        '--width', [string]$width,
        '--height', [string]$height,
        '--seed', [string]$seed,
        '--output', $outputPath,
        '--diffusion-fa',
        '--vae-tiling'
    )
    if ($Payload.offloadToCpu -eq $true) { $arguments += '--offload-to-cpu' }

    $log = (& $SdBinary @arguments 2>&1 | Out-String)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -or -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        if ($log.Length -gt 2000) { $log = $log.Substring($log.Length - 2000) }
        throw "Image generation failed (exit $exitCode): $log"
    }
    return @{ imageUrl = "http://127.0.0.1:$port/images/$filename"; filename = $filename; seed = $seed }
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
            if ($method -eq 'GET' -and $path -eq '/health') {
                Send-JsonResponse $stream 200 @{ status = 'ready'; model = $defaultModel }
                continue
            }
            if ($method -eq 'GET' -and $path -eq '/models') {
                Update-ImageModels
                $availableModels = @($models.Keys | Sort-Object | ForEach-Object {
                    @{ id = $_; label = $models[$_].Label; steps = $models[$_].Steps }
                })
                Send-JsonResponse $stream 200 @{ default = $defaultModel; models = $availableModels }
                continue
            }
            if ($method -eq 'GET' -and $path -match '^/images/([^/]+\.png)$') {
                $imagePath = Join-Path $OutputDirectory ([System.IO.Path]::GetFileName($matches[1]))
                if (Test-Path -LiteralPath $imagePath -PathType Leaf) {
                    Send-Response $stream 200 'image/png' ([System.IO.File]::ReadAllBytes($imagePath))
                } else {
                    Send-JsonResponse $stream 404 @{ error = 'image not found' }
                }
                continue
            }
            if ($method -ne 'POST' -or $path -ne '/generate') {
                Send-JsonResponse $stream 404 @{ error = 'not found' }
                continue
            }

            try {
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
                Send-JsonResponse $stream 200 (Invoke-ImageGeneration $payload)
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