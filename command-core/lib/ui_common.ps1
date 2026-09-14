# ANSI Colors
$ESC    = "$([char]27)"
$NEON_PINK = "$([char]27)[38;5;213m"
$PINK   = "$([char]27)[38;5;205m"
$ORANGE = "$([char]27)[38;5;214m"
$SUNSET_ORANGE = "$([char]27)[38;5;208m"
$VIOLET = "$([char]27)[38;5;99m"
$AQUA   = "$([char]27)[38;5;45m"
$CYAN   = "$([char]27)[38;5;51m"
$PURPLE = "$([char]27)[38;5;93m"
$WHITE  = "$([char]27)[1;37m"
$GREEN  = "$([char]27)[38;5;82m"
$RED    = "$([char]27)[38;5;196m"
$BOLD   = "$([char]27)[1m"
$RESET  = "$([char]27)[0m"

function Draw-Banner {
    Clear-Host
    $bannerFile = Join-Path $USB_ROOT "command-core\banner.txt"
    if (Test-Path $bannerFile) {
        $lines = Get-Content $bannerFile
        $bannerPalette = @($NEON_PINK, $PINK, $VIOLET, $AQUA, $CYAN)
        $lineNum = 1
        foreach ($line in $lines) {
            if ($line.Contains("COMMAND CONSOLE")) {
                Write-Host "$BOLD$SUNSET_ORANGE$line$RESET"
                $lineNum++
                continue
            }
            $color = $bannerPalette[($lineNum - 1) % $bannerPalette.Count]
            $style = if ($lineNum -le 3) { $BOLD } else { "" }
            Write-Host "$style$color$line$RESET"
            $lineNum++
        }
    }
    Write-Host ""
}

# CENTRAL PHRASES
function Get-Phrases {
    $phrasesFile = Join-Path $USB_ROOT "command-core\phrases.txt"
    $phrases = @()
    if (Test-Path $phrasesFile) {
        $phrases = @(Get-Content $phrasesFile -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    }
    if ($phrases.Count -eq 0) {
        $phrases = @(
            "Bypassing the mainframe flux capacitor...",
            "Downloading more RAM from the cloud matrix...",
            "Consulting the cyber oracle for terminal wisdom...",
            "Calibrating optical cyber-lasers...",
            "Re-routing the warp drive through port 9931...",
            "Synthesizing extra gigawatts of neon energy...",
            "Decrypting secret coffee recipes...",
            "Overclocking quantum hamsters...",
            "Engaging Miami Vice neon turbo-boosters...",
            "Compiling discrete custom terminal pipeline..."
        )
    }
    return $phrases
}

# UNCENSORED AI STUDIO INTEGRATION HELPERS
function Get-UncensoredStudioPath {
    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
        $candidates += Join-Path $env:USERPROFILE "GitHub\Uncensored-Local-Studio"
    }
    if (-not [string]::IsNullOrWhiteSpace($env:HOME)) {
        $candidates += Join-Path $env:HOME "GitHub/Uncensored-Local-Studio"
    }
    $candidates += "/home/cyb3rcat/GitHub/Uncensored-Local-Studio"
    $candidates += "C:\GitHub\Uncensored-Local-Studio"
    if (-not [string]::IsNullOrWhiteSpace($USB_ROOT)) {
        $candidates += Join-Path (Split-Path $USB_ROOT -Parent) "Uncensored-Local-Studio"
    }

    foreach ($p in $candidates) {
        if (-not [string]::IsNullOrWhiteSpace($p) -and (Test-Path $p)) {
            return $p
        }
    }
    return $null
}

function Get-DiscoveredModelFiles {
    $found = @()
    $studioPath = Get-UncensoredStudioPath

    # 1. USB models
    $usbModelsDir = Join-Path $USB_ROOT "models"
    if (Test-Path $usbModelsDir) {
        Get-ChildItem -Path $usbModelsDir -Filter "*.gguf" -ErrorAction SilentlyContinue | ForEach-Object {
            $found += [PSCustomObject]@{
                Name = $_.Name
                FullName = $_.FullName
                Source = "USB"
            }
        }
    }

    # 2. Uncensored-Local-Studio models (app\llm-models and app\models)
    if ($studioPath) {
        $studioLlmDir = Join-Path $studioPath "app\llm-models"
        if (Test-Path $studioLlmDir) {
            Get-ChildItem -Path $studioLlmDir -Filter "*.gguf" -ErrorAction SilentlyContinue | ForEach-Object {
                $fName = $_.Name
                if (-not ($found | Where-Object { $_.Name -eq $fName })) {
                    $found += [PSCustomObject]@{
                        Name = $fName
                        FullName = $_.FullName
                        Source = "Uncensored-Studio"
                    }
                }
            }
        }
        $studioAppModelsDir = Join-Path $studioPath "app\models"
        if (Test-Path $studioAppModelsDir) {
            Get-ChildItem -Path $studioAppModelsDir -Filter "*.gguf" -ErrorAction SilentlyContinue | ForEach-Object {
                $fName = $_.Name
                if (-not ($found | Where-Object { $_.Name -eq $fName })) {
                    $found += [PSCustomObject]@{
                        Name = $fName
                        FullName = $_.FullName
                        Source = "Uncensored-Studio"
                    }
                }
            }
        }
    }

    return $found
}

function Resolve-ModelPath([string]$modelName) {
    if ([string]::IsNullOrWhiteSpace($modelName)) { return $null }
    if (Test-Path $modelName) { return $modelName }

    $all = Get-DiscoveredModelFiles
    $match = $all | Where-Object { $_.Name -eq $modelName -or $_.FullName -eq $modelName } | Select-Object -First 1
    if ($match) { return $match.FullName }

    $usbPath = Join-Path $USB_ROOT "models\$modelName"
    if (Test-Path $usbPath) { return $usbPath }

    $studioPath = Get-UncensoredStudioPath
    if ($studioPath) {
        $st1 = Join-Path $studioPath "app\llm-models\$modelName"
        if (Test-Path $st1) { return $st1 }
        $st2 = Join-Path $studioPath "app\models\$modelName"
        if (Test-Path $st2) { return $st2 }
    }

    return $null
}

# ACTIVE MODEL MANAGEMENT
function Get-ActiveModel {
    $modelConf = Join-Path $USB_ROOT "command-core\active_model.txt"
    $selectedModel = ""
    if (Test-Path $modelConf) {
        $selectedModel = (Get-Content $modelConf -ErrorAction SilentlyContinue | Out-String).Trim()
    }
    $resolved = Resolve-ModelPath $selectedModel
    if ([string]::IsNullOrWhiteSpace($selectedModel) -or -not $resolved) {
        $all = Get-DiscoveredModelFiles
        if ($all.Count -gt 0) {
            $selectedModel = $all[0].Name
            $selectedModel | Out-File -FilePath $modelConf -Encoding UTF8
        }
    }
    return $selectedModel
}

function Download-ModelMenu {
    Draw-Banner
    Write-Host "$CYAN─── [MODEL DOWNLOAD CENTER] ────────────────────────────$RESET`n"
    Write-Host "  $CYAN[1]$RESET Qwen2.5 Coder 0.5B Q4_K_M $PURPLE[~491 MB]$RESET"
    Write-Host "  $CYAN[2]$RESET Direct HTTPS link to a .gguf file"
    Write-Host "  $ORANGE[Enter]$RESET Cancel"
    Write-Host ""
    Write-Host -NoNewline "$ORANGESelect download source: $RESET"
    $downloadChoice = Read-Host

    $modelUrl = ""
    $modelName = ""
    switch ($downloadChoice) {
        "1" {
            $modelName = "qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
            $modelUrl = "https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/$modelName"
        }
        "2" {
            Write-Host -NoNewline "$ORANGEPaste direct HTTPS .gguf URL: $RESET"
            $modelUrl = Read-Host
            $uri = $null
            if (-not [Uri]::TryCreate($modelUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') {
                Write-Host "$RED[!] URL must use HTTPS and end with a safe .gguf filename.$RESET"
                Start-Sleep -Seconds 1.5
                return
            }
            $modelName = [Uri]::UnescapeDataString([IO.Path]::GetFileName($uri.AbsolutePath))
            if ($modelName -notmatch '^[A-Za-z0-9._+-]+\.gguf$') {
                Write-Host "$RED[!] URL must use HTTPS and end with a safe .gguf filename.$RESET"
                Start-Sleep -Seconds 1.5
                return
            }
        }
        Default { return }
    }

    $modelsDir = Join-Path $USB_ROOT "models"
    $targetPath = Join-Path $modelsDir $modelName
    $partPath = "$targetPath.part"
    New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null

    if (Test-Path $targetPath) {
        $replaceModel = Read-Host "$modelName already exists. Replace it? [y/N]"
        if ($replaceModel -notmatch '^[Yy]$') { return }
    }

    Remove-Item $partPath -Force -ErrorAction SilentlyContinue
    Write-Host "$CYAN[>>] Downloading $WHITE$modelName$RESET"
    try {
        Invoke-WebRequest -Uri $modelUrl -OutFile $partPath -UseBasicParsing
        if (-not (Test-Path $partPath) -or (Get-Item $partPath).Length -eq 0) {
            throw "Download produced an empty file."
        }
        Move-Item -Path $partPath -Destination $targetPath -Force
    } catch {
        Remove-Item $partPath -Force -ErrorAction SilentlyContinue
        Write-Host "$RED[!] Model download failed: $($_.Exception.Message)$RESET"
        return
    }
    Write-Host "$GREEN[✓] Model saved to: $targetPath$RESET"

    $activateModel = Read-Host "Activate this model now? [y/N]"
    if ($activateModel -match '^[Yy]$') {
        $modelName | Out-File -FilePath (Join-Path $USB_ROOT "command-core\active_model.txt") -Encoding UTF8
        Write-Host "$PINK[+] Active model: $WHITE$modelName$RESET"
        Restart-Engine
    }
}

function Select-ModelMenu {
    Draw-Banner
    Write-Host "$CYAN─── [NEURAL MODEL REGISTRY] ────────────────────────────$RESET`n"
    
    $currentModel = Get-ActiveModel
    $models = Get-DiscoveredModelFiles
    
    if ($models.Count -eq 0) {
        Write-Host "$RED[!] No .gguf models discovered inside USB or Uncensored AI Studio directories.$RESET"
    }

    $idx = 1
    foreach ($m in $models) {
        $sourceLabel = "$PURPLE[$($m.Source)]$RESET"
        if ($m.Name -eq $currentModel -or $m.FullName -eq $currentModel) {
            Write-Host "  $PINK[$idx]$RESET $WHITE$($m.Name)$RESET $sourceLabel $GREEN<<< ACTIVE >>$RESET"
        } else {
            Write-Host "  $CYAN[$idx]$RESET $WHITE$($m.Name)$RESET $sourceLabel"
        }
        $idx++
    }

    Write-Host ""
    Write-Host "  $CYAN[D]$RESET Download another GGUF model"
    Write-Host -NoNewline "$ORANGESelect a model, [D] to download, or press Enter to keep current: $RESET"
    $choice = Read-Host

    if ($choice -match '^[Dd]$') {
        Download-ModelMenu
    } elseif ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $models.Count) {
        $newModel = $models[[int]$choice - 1].Name
        $modelConf = Join-Path $USB_ROOT "command-core\active_model.txt"
        $newModel | Out-File -FilePath $modelConf -Encoding UTF8
        Write-Host "`n$PINK[+] Switched active model to: $WHITE$newModel$RESET"
        Restart-Engine
    } else {
        Write-Host "`n$CYAN[*] Active model unchanged: $currentModel$RESET"
        Start-Sleep -Seconds 1
    }
}

# ENGINE LIFECYCLE CONTROLLERS
function Get-EngineBinary {
    $usbBin = Join-Path $USB_ROOT "bin\win-x64\llama-server.exe"
    if (Test-Path $usbBin) { return $usbBin }

    $studioPath = Get-UncensoredStudioPath
    if ($studioPath) {
        $candidates = @(
            (Join-Path $studioPath "app\llm-backend\win\cuda\llama-server.exe"),
            (Join-Path $studioPath "app\llm-backend\win\vulkan\llama-server.exe"),
            (Join-Path $studioPath "app\llm-backend\win\hip\llama-server.exe"),
            (Join-Path $studioPath "app\llm-backend\win\sycl\llama-server.exe"),
            (Join-Path $studioPath "app\llm-backend\win\cpu\llama-server.exe")
        )
        foreach ($cand in $candidates) {
            if (Test-Path $cand) { return $cand }
        }
    }
    return $null
}

function Get-ActiveLlmPort {
    if ($global:ACTIVE_LLM_PORT) { return $global:ACTIVE_LLM_PORT }

    foreach ($p in @(10086, 9931)) {
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$p/v1/models" -TimeoutSec 1 -ErrorAction Stop
            if ($resp) {
                $global:ACTIVE_LLM_PORT = $p
                return $p
            }
        } catch { }
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$p/health" -TimeoutSec 1 -ErrorAction Stop
            if ($resp.status -eq 'ok') {
                $global:ACTIVE_LLM_PORT = $p
                return $p
            }
        } catch { }
    }
    $global:ACTIVE_LLM_PORT = 9931
    return 9931
}

function Wait-ForServer($Port = 9931, $MaxWait = 35) {
    Write-Host "$CYAN[*] Booting Neural Engine (loading weights into RAM)...$RESET"
    $count = 0
    while ($count -lt $MaxWait) {
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 1 -ErrorAction Stop
            if ($resp.status -eq 'ok') {
                Write-Host "`r$ESC[K    $GREEN[✓] Engine Ready & Online on Port $Port.$RESET"
                Start-Sleep -Milliseconds 500
                return $true
            }
        } catch { }
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/v1/models" -TimeoutSec 1 -ErrorAction Stop
            if ($resp) {
                Write-Host "`r$ESC[K    $GREEN[✓] Engine Ready & Online on Port $Port.$RESET"
                Start-Sleep -Milliseconds 500
                return $true
            }
        } catch { }
        Write-Host -NoNewline "`r$ESC[K    $PINK[*] Loading Tensor Core... ($($count)s/$($MaxWait)s)$RESET"
        Start-Sleep -Seconds 1
        $count++
    }
    Write-Host "`r$ESC[K    $ORANGE[!] Engine taking longer to respond.$RESET"
    return $false
}

function Stop-Engine {
    Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
}

function Start-HistoryServer {
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:9932/history" -TimeoutSec 1 -ErrorAction Stop | Out-Null
        return $true
    } catch { }

    $scriptPath = Join-Path $USB_ROOT "command-core\lib\history_server.ps1"
    $historyPath = Join-Path $USB_ROOT "command-core\chat_history.json"
    $powerShellPath = (Get-Process -Id $PID).Path
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -HistoryFile `"$historyPath`""
    $global:HISTORY_SERVER_PROCESS = Start-Process -FilePath $powerShellPath -ArgumentList $arguments -WindowStyle Hidden -PassThru

    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            Invoke-RestMethod -Uri "http://127.0.0.1:9932/history" -TimeoutSec 1 -ErrorAction Stop | Out-Null
            return $true
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }

    Write-Host "$ORANGE[!] Chat history service failed to start.$RESET"
    Stop-HistoryServer
    return $false
}

function Stop-HistoryServer {
    if ($global:HISTORY_SERVER_PROCESS -and -not $global:HISTORY_SERVER_PROCESS.HasExited) {
        Stop-Process -Id $global:HISTORY_SERVER_PROCESS.Id -Force -ErrorAction SilentlyContinue
    }
    $global:HISTORY_SERVER_PROCESS = $null
}

function Start-ImageServer {
    try {
        Invoke-RestMethod -Uri 'http://127.0.0.1:9933/health' -TimeoutSec 1 -ErrorAction Stop | Out-Null
        Write-Host "$GREEN[✓] Z-Image Turbo service is online on Port 9933.$RESET"
        return $true
    } catch { }

    $binRoot = Join-Path $USB_ROOT 'bin\win-x64\image'
    $sdBinary = Get-ChildItem -Path $binRoot -Filter 'sd-cli.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    $modelDir = Join-Path $USB_ROOT 'models\image\z-image-turbo'
    $diffusionModel = Join-Path $modelDir 'z_image_turbo-Q3_K.gguf'
    $vaeModel = Join-Path $modelDir 'ae.safetensors'
    $llmModel = Join-Path $modelDir 'Qwen3-4B-Instruct-2507-Q4_K_M.gguf'
    if (-not $sdBinary -or -not (Test-Path $diffusionModel) -or -not (Test-Path $vaeModel) -or -not (Test-Path $llmModel)) {
        Write-Host "$ORANGE[*] Z-Image Turbo is not installed. Run setup to enable image generation.$RESET"
        return $false
    }

    $scriptPath = Join-Path $USB_ROOT 'command-core\lib\image_server.ps1'
    $outputDirectory = Join-Path $USB_ROOT 'generated-images'
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    $powerShellPath = (Get-Process -Id $PID).Path
    $quotedValues = @($scriptPath, $sdBinary.FullName, $diffusionModel, $vaeModel, $llmModel, $outputDirectory) |
        ForEach-Object { '"{0}"' -f ($_ -replace '"', '\"') }
    $arguments = '-NoProfile -ExecutionPolicy Bypass -File {0} -SdBinary {1} -DiffusionModel {2} -VaeModel {3} -LlmModel {4} -OutputDirectory {5}' -f $quotedValues
    $global:IMAGE_SERVER_PROCESS = Start-Process -FilePath $powerShellPath -ArgumentList $arguments -WindowStyle Hidden -PassThru
    for ($attempt = 0; $attempt -lt 20; $attempt++) {
        try {
            Invoke-RestMethod -Uri 'http://127.0.0.1:9933/health' -TimeoutSec 1 -ErrorAction Stop | Out-Null
            Write-Host "$GREEN[✓] Z-Image Turbo service is online on Port 9933.$RESET"
            return $true
        } catch {
            Start-Sleep -Milliseconds 100
        }
    }
    Write-Host "$ORANGE[!] Z-Image Turbo service failed to start.$RESET"
    Stop-ImageServer
    return $false
}

function Stop-ImageServer {
    if ($global:IMAGE_SERVER_PROCESS -and -not $global:IMAGE_SERVER_PROCESS.HasExited) {
        Stop-Process -Id $global:IMAGE_SERVER_PROCESS.Id -Force -ErrorAction SilentlyContinue
    }
    $global:IMAGE_SERVER_PROCESS = $null
}

function Start-Engine {
    # Reuse running LLM server on 10086 (Uncensored Studio) or 9931 if online
    foreach ($p in @(10086, 9931)) {
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$p/v1/models" -TimeoutSec 1 -ErrorAction Stop
            if ($resp) {
                Write-Host "$GREEN[✓] Reusing active LLM Engine server on Port $p.$RESET"
                $global:ACTIVE_LLM_PORT = $p
                return
            }
        } catch { }
    }

    $activeModelName = Get-ActiveModel
    $modelFile = Resolve-ModelPath $activeModelName
    $serverExe = Get-EngineBinary

    if (-not $serverExe -or -not $modelFile) {
        Write-Host "$RED[!] Required backend or model missing. Run setup-windows.ps1 first.$RESET"
        return
    }

    Stop-Engine
    $webUiPath = Join-Path $USB_ROOT "command-core\webui"
    $targetPort = 9931
    $global:ACTIVE_LLM_PORT = $targetPort

    if (-not $modelFile -or -not (Test-Path $modelFile)) {
        Write-Host "$RED[!] Error: Model file not found for: $activeModelName$RESET"
        return
    }

    if ($serverExe -and (Test-Path $serverExe)) {
        $serverBinDir = Split-Path -Parent $serverExe
        Start-Process -FilePath $serverExe -WorkingDirectory $serverBinDir -ArgumentList "-m `"$modelFile`" -c 4096 --host 0.0.0.0 --port $targetPort --path `"$webUiPath`"" -WindowStyle Hidden
        Wait-ForServer -Port $targetPort -MaxWait 35
    } else {
        Write-Host "$RED[!] Error: llama-server.exe binary not found. Run setup-windows.ps1.$RESET"
    }
}

function Restart-Engine {
    Start-Engine
}

# CUSTOM SKILL / TOOL REGISTRY MANAGEMENT
function Get-SkillsManifest {
    $skillsDir = Join-Path $USB_ROOT "tactics"
    $manifest = ""
    if (Test-Path $skillsDir) {
        $files = Get-ChildItem -Path $skillsDir -File | Where-Object { $_.Extension -in @(".ps1", ".py", ".sh") }
        foreach ($sFile in $files) {
            $content = Get-Content $sFile.FullName -ErrorAction SilentlyContinue
            $sName = ""
            $sDesc = ""
            foreach ($line in $content) {
                if ($line -match '^#\s*NAME:\s*(.+)$') { $sName = $matches[1].Trim() }
                if ($line -match '^#\s*DESC:\s*(.+)$') { $sDesc = $matches[1].Trim() }
            }
            if ([string]::IsNullOrWhiteSpace($sName)) { $sName = $sFile.BaseName }
            $manifest += "$($sFile.Name): $sName ($sDesc); "
        }
    }
    return $manifest
}

function Try-DirectSkillExecution($userInput) {
    $skillsDir = Join-Path $USB_ROOT "tactics"
    $cleanInput = $userInput -replace '^[/@]', '' -replace '^(?i)(skill:|run:|use skill:?)\s*', ''
    $parts = $cleanInput.Split(' ', 2)
    $firstWord = $parts[0].Trim()
    $restArgs = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "" }

    $targetScript = $null
    foreach ($ext in @(".ps1", ".py", ".sh", "")) {
        $candidate = Join-Path $skillsDir ($firstWord + $ext)
        if (Test-Path $candidate) {
            $targetScript = $candidate
            break
        }
    }

    if (-not $targetScript) {
        $slugMatch = $firstWord -replace '-', '_'
        foreach ($ext in @(".ps1", ".py", ".sh")) {
            $candidate = Join-Path $skillsDir ($slugMatch + $ext)
            if (Test-Path $candidate) {
                $targetScript = $candidate
                break
            }
        }
    }

    if ($targetScript) {
        if ($targetScript.EndsWith(".py")) {
            return "python3 `"$targetScript`" $restArgs"
        } elseif ($targetScript.EndsWith(".ps1")) {
            return "& `"$targetScript`" -Target `"$restArgs`""
        } else {
            return "bash `"$targetScript`" $restArgs"
        }
    }
    return $null
}

# CUSTOM SKILL / TOOL REGISTRY MANAGEMENT
function Execute-CustomSkillMenu {
    $skillsDir = Join-Path $USB_ROOT "tactics"
    if (-not (Test-Path $skillsDir)) {
        New-Item -ItemType Directory -Path $skillsDir -Force > $null
    }

    while ($true) {
        Draw-Banner
        Write-Host "$PINK[WARSTICK TACTICAL MODULES]$RESET`n"

        $skillFiles = @()
        $skillNames = @()
        $skillDescs = @()
        $skillNeedsArgs = @()
        $idx = 1

        $files = Get-ChildItem -Path $skillsDir -File | Where-Object { $_.Extension -in @(".ps1", ".py", ".sh") }
        foreach ($sFile in $files) {
            $content = Get-Content $sFile.FullName -ErrorAction SilentlyContinue

            $sName = ""
            $sDesc = ""
            $sArgs = ""

            foreach ($line in $content) {
                if ($line -match '^#\s*NAME:\s*(.+)$') { $sName = $matches[1].Trim() }
                if ($line -match '^#\s*DESC:\s*(.+)$') { $sDesc = $matches[1].Trim() }
                if ($line -match '^#\s*ARGS:\s*(.+)$') { $sArgs = $matches[1].Trim() }
            }

            if ([string]::IsNullOrWhiteSpace($sName)) {
                $sName = ($sFile.BaseName -replace '_', ' ')
            }
            if ([string]::IsNullOrWhiteSpace($sDesc)) {
                $sDesc = "Execute modular script: $($sFile.Name)"
            }
            if ([string]::IsNullOrWhiteSpace($sArgs)) {
                if ($content -match 'param\(\[string\]\$Target\)|sys\.argv|\$args') {
                    $sArgs = "true"
                } else {
                    $sArgs = "false"
                }
            }

            $skillFiles += $sFile.FullName
            $skillNames += $sName
            $skillDescs += $sDesc
            $skillNeedsArgs += $sArgs

            Write-Host "  $CYAN[$idx]$RESET $WHITE$sName$RESET $PURPLE($($sFile.Name))$RESET"
            Write-Host "      $PURPLE↳ $sDesc$RESET"
            $idx++
        }

        if ($skillFiles.Count -eq 0) {
            Write-Host "  $ORANGE[!] No tactical modules discovered inside tactics\$RESET"
            Write-Host "      $WHITEAdd .ps1, .py, or .sh modules to tactics\. See tactics\README.md for the format.$RESET`n"
        }

        Write-Host "`n  $PINK[+]$RESET Create New Tactical Module Template"
        Write-Host "  $ORANGE[B]$RESET Back to Main Matrix`n"
        Write-Host -NoNewline "$ORANGESelect skill action (1-$($skillFiles.Count), +, B): $RESET"
        $skChoice = Read-Host

        if ($skChoice -match '^[bB]$') {
            break
        } elseif ($skChoice -eq '+') {
            Draw-Banner
            Write-Host "$PINK─── [CREATE MODULAR SKILL TEMPLATE] ────────────────────$RESET`n"
            Write-Host -NoNewline "$CYANEnter File Identifier (e.g. url_scanner or port_probe): $RESET"
            $rawSlug = Read-Host
            if ([string]::IsNullOrWhiteSpace($rawSlug)) { continue }
            $slug = ($rawSlug -replace ' ', '_' -replace '[^a-zA-Z0-9_-]', '')

            Write-Host -NoNewline "$CYANEnter Skill Display Name: $RESET"
            $newName = Read-Host
            if ([string]::IsNullOrWhiteSpace($newName)) { $newName = $slug }

            Write-Host -NoNewline "$CYANEnter Short Description: $RESET"
            $newDesc = Read-Host
            if ([string]::IsNullOrWhiteSpace($newDesc)) { $newDesc = "Custom automated offensive skill" }

            Write-Host -NoNewline "$CYANDoes this skill require a target argument (domain, IP, URL)? (y/n): $RESET"
            $hasArg = Read-Host
            $argsVal = if ($hasArg -match '^[yY]$') { "true" } else { "false" }

            $newFile = Join-Path $skillsDir "${slug}.ps1"
            @"
# NAME: $newName
# DESC: $newDesc
# ARGS: $argsVal
param([string]`$Target)

Write-Host "[*] Executing $newName..." -ForegroundColor Cyan
if (`$Target) {
    Write-Host "Processing target: `$Target" -ForegroundColor White
}
"@ | Out-File -FilePath $newFile -Encoding UTF8

            Write-Host "`n$GREEN[✓] Tactical module created at: ${WHITE}tactics\${slug}.ps1$RESET"
            Write-Host "$CYAN[*] You can customize its PowerShell logic at any time.$RESET"
            Start-Sleep -Seconds 1.5
            continue
        } elseif ($skChoice -match '^\d+$' -and [int]$skChoice -ge 1 -and [int]$skChoice -le $skillFiles.Count) {
            $sIndex = [int]$skChoice - 1
            $chosenFile = $skillFiles[$sIndex]
            $chosenName = $skillNames[$sIndex]
            $chosenArgs = $skillNeedsArgs[$sIndex]
            $fileName   = Split-Path -Leaf $chosenFile

            Draw-Banner
            Write-Host "$PINK[!] SKILL ACTIVATED ->$RESET $WHITE$chosenName$RESET`n"

            $targetArg = ""
            if ($chosenArgs -eq "true") {
                Write-Host -NoNewline "$ORANGEEnter target parameter (domain, IP, URL, or host): $RESET"
                $targetArg = Read-Host
                if ([string]::IsNullOrWhiteSpace($targetArg)) { continue }
            }

            $logsDir = Join-Path $USB_ROOT "warstick-logs"
            if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force > $null }

            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $sessionLog = Join-Path $logsDir "skill_${timestamp}.txt"
            $masterLog  = Join-Path $USB_ROOT "warstick-logs\warstick.log"

            $sessionHeader = "===============================================================================`r`n[WARSTICK SKILL EXECUTION - $timestamp]`r`nSkill Name : $chosenName`r`nScript     : $fileName`r`nTarget     : $(if ($targetArg) { $targetArg } else { 'N/A' })`r`n==============================================================================="
            $sessionHeader | Out-File -FilePath $sessionLog -Encoding UTF8
            "`r`n$sessionHeader" | Out-File -FilePath $masterLog -Append -Encoding UTF8

            Write-Host "$PINK[>] Invoking Modular Skill: $RESET$WHITE$fileName $targetArg$RESET"
            Write-Host "`n$CYAN--- SKILL RUNTIME OUTPUT ---$RESET"

            try {
                if ($chosenFile.EndsWith(".py")) {
                    if (Get-Command python3 -ErrorAction SilentlyContinue) {
                        $cmdOutput = (python3 "$chosenFile" "$targetArg" 2>&1 | Out-String)
                    } elseif (Get-Command python -ErrorAction SilentlyContinue) {
                        $cmdOutput = (python "$chosenFile" "$targetArg" 2>&1 | Out-String)
                    } else {
                        $cmdOutput = "Error: Python is not installed on this system. Cannot execute .py skill."
                    }
                } elseif ($chosenFile.EndsWith(".ps1")) {
                    $cmdOutput = (& "$chosenFile" -Target "$targetArg" 2>&1 | Out-String)
                } else {
                    $cmdOutput = (bash "$chosenFile" "$targetArg" 2>&1 | Out-String)
                }
            } catch {
                $cmdOutput = $_.Exception.Message
            }
            Write-Host $cmdOutput
            $cmdOutput | Out-File -FilePath $sessionLog -Append -Encoding UTF8
            $cmdOutput | Out-File -FilePath $masterLog -Append -Encoding UTF8

            $summaryBlock = "`r`n===============================================================================`r`n[SKILL SUMMARY]`r`nSkill   : $chosenName`r`nScript  : $fileName`r`nStatus  : EXECUTED`r`n===============================================================================`r`n"
            $summaryBlock | Out-File -FilePath $sessionLog -Append -Encoding UTF8
            $summaryBlock | Out-File -FilePath $masterLog -Append -Encoding UTF8

            Write-Host "`n$GREEN[✓] Skill execution completed.$RESET"
            Write-Host "$CYAN[*] Log saved to: ${WHITE}warstick-logs\skill_${timestamp}.txt$RESET"
            Read-Host "Press [Enter] to continue..."
        } else {
            Write-Host "$RED[!] Invalid choice.$RESET"
            Start-Sleep -Seconds 1
        }
    }
}

function Query-LlmWithAnimation($Payload) {
    $phrases = Get-Phrases
    $glyphs = @("◢", "◣", "◤", "◥", "█", "▓", "▒", "░", "◆", "◇", "◈", "▲", "▼")
    $colors = @($PINK, $ORANGE, $CYAN, $PURPLE)

    $port = Get-ActiveLlmPort
    $currentPhrase = $phrases[(Get-Random -Maximum $phrases.Count)]
    Write-Host "$CYAN[*] Initializing Neural Bus...$RESET"

    $job = Start-Job -ScriptBlock {
        param($body, $serverPort)
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$serverPort/v1/chat/completions" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120
            return ($resp | ConvertTo-Json -Depth 10 -Compress)
        } catch {
            return $_.Exception.Message
        }
    } -ArgumentList $Payload, $port

    $tick = 0
    while ($job.State -eq 'Running') {
        $tick++
        if ($tick % 38 -eq 0) {
            $currentPhrase = $phrases[(Get-Random -Maximum $phrases.Count)]
        }
        $g1 = $glyphs[(Get-Random -Maximum $glyphs.Count)]
        $g2 = $glyphs[(Get-Random -Maximum $glyphs.Count)]
        $c1 = $colors[(Get-Random -Maximum $colors.Count)]
        $c2 = $colors[(Get-Random -Maximum $colors.Count)]
        $hz = Get-Random -Minimum 120 -Maximum 960

        Write-Host -NoNewline "`r$ESC[K    $c1[$g1$c2$g2$c1]$RESET $currentPhrase $WHITE$($hz)Hz$RESET "
        Start-Sleep -Milliseconds 120
    }

    $raw = Receive-Job -Job $job
    Remove-Job -Job $job -Force > $null
    Write-Host "`r$ESC[K    $CYAN[✓] Neural Synthesis Complete.$RESET"
    return $raw
}

function Test-PowerShellCommandSyntax([string]$CommandText) {
    if ([string]::IsNullOrWhiteSpace($CommandText)) {
        return $false
    }

    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput(
        $CommandText,
        [ref]$tokens,
        [ref]$parseErrors
    )
    return $parseErrors.Count -eq 0
}

function Clean-JsonCommand($raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return "ERROR: Empty response received from model."
    }

    if ($raw -match '(?i)^(The underlying connection|Unable to connect|The remote server|Exception:|Error:|\s*System\.)') {
        return "ERROR: $raw"
    }

    $content = ""
    $reasoning = ""

    try {
        $jsonObj = $raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($jsonObj.choices -and $jsonObj.choices.Count -gt 0) {
            $msg = $jsonObj.choices[0].message
            if ($msg.content) { $content = $msg.content.Trim() }
            if ($msg.reasoning_content) { $reasoning = $msg.reasoning_content.Trim() }
        }
    } catch { }

    if ([string]::IsNullOrWhiteSpace($content) -and -not [string]::IsNullOrWhiteSpace($reasoning)) {
        $content = $reasoning
    } elseif ([string]::IsNullOrWhiteSpace($content)) {
        $content = $raw
    }

    # 1. Strip think/thought XML tags
    $content = $content -replace '(?s)<think>.*?</think>', ''
    $content = $content -replace '(?s)<thought>.*?</thought>', ''

    # 2. Extract code block if wrapped in markdown
    if ($content -match '(?s)```(?:bash|sh|zsh|powershell|cmd|batch)?\s*\r?\n?(.*?)\r?\n?```') {
        $content = $matches[1].Trim()
    }

    # 3. Filter lines
    $lines = $content -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    $validLines = @()
    foreach ($line in $lines) {
        if ($line -match '^(\{|\}|\[|\]|"|choices:|data:|\#|---|===)') { continue }
        if ($line -match '^(?i)(We need|Let\x27s|I will|The user|First,|Note:|Option|Step \d|Here is|To accomplish|This command)') { continue }
        $validLines += $line
    }

    $finalCmd = ""
    if ($validLines.Count -gt 0) {
        foreach ($candidate in $validLines) {
            if ($candidate -notmatch '[\.\?\!]$' -and $candidate -notmatch '^//') {
                $finalCmd = $candidate
                break
            }
        }
        if (-not $finalCmd) { $finalCmd = $validLines[0] }
    } elseif ($lines.Count -gt 0) {
        $finalCmd = $lines[-1]
    }

    $finalCmd = $finalCmd -replace '^`+|`+$', ''
    $finalCmd = $finalCmd -replace '\\n', ' ' -replace '\\t', ' '

    if ($finalCmd -match '^(\{|choices:|\[\{)') {
        $finalCmd = ""
    }

    # Detect unpopulated placeholder templates
    if ($finalCmd -match '(?i)<[a-zA-Z0-9_\-]+>|\[(target|ip|port|host|username|password|path|file)') {
        return "TEMPLATE: $finalCmd"
    }

    if ($finalCmd -match "(?i)(cannot assist|sorry|illegal|unethical|certified security|as an ai|i am unable|as a language model|policy|disclaimer)") {
        return "REFUSAL: $finalCmd"
    }
    if ([string]::IsNullOrWhiteSpace($finalCmd)) {
        return "ERROR: Model did not produce a clean executable command."
    }
    return $finalCmd
}
