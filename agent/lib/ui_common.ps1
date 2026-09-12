# ─── CENTRALIZED UI & OPERATIONAL LIBRARY (WINDOWS POWERSHELL) ───

# ANSI Colors
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
    $bannerFile = Join-Path $USB_ROOT "agent\banner.txt"
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

# ─── ACTIVE MODEL MANAGEMENT ─────────────────────────────────────
function Get-ActiveModel {
    $modelConf = Join-Path $USB_ROOT "agent\active_model.txt"
    $selectedModel = ""
    if (Test-Path $modelConf) {
        $selectedModel = (Get-Content $modelConf -ErrorAction SilentlyContinue | Out-String).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($selectedModel) -or (-not (Test-Path (Join-Path $USB_ROOT "models\$selectedModel")))) {
        $found = Get-ChildItem (Join-Path $USB_ROOT "models") -Filter "*.gguf" | Select-Object -First 1
        if ($found) {
            $selectedModel = $found.Name
            $selectedModel | Out-File -FilePath $modelConf -Encoding UTF8
        }
    }
    return $selectedModel
}

function Select-ModelMenu {
    Draw-Banner
    Write-Host "$CYAN─── [NEURAL MODEL REGISTRY] ────────────────────────────$RESET`n"
    
    $currentModel = Get-ActiveModel
    $models = @(Get-ChildItem (Join-Path $USB_ROOT "models") -Filter "*.gguf")
    
    if ($models.Count -eq 0) {
        Write-Host "$RED[!] No .gguf models discovered inside USB \models directory.$RESET"
        Read-Host "Press [Enter] to return..."
        return
    }

    $idx = 1
    foreach ($m in $models) {
        if ($m.Name -eq $currentModel) {
            Write-Host "  $PINK[$idx]$RESET $WHITE$($m.Name)$RESET $GREEN<<< ACTIVE >>$RESET"
        } else {
            Write-Host "  $CYAN[$idx]$RESET $WHITE$($m.Name)$RESET"
        }
        $idx++
    }

    Write-Host ""
    Write-Host -NoNewline "$ORANGESelect target model index (1-$($models.Count)) or press Enter to keep current: $RESET"
    $choice = Read-Host

    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $models.Count) {
        $newModel = $models[[int]$choice - 1].Name
        $modelConf = Join-Path $USB_ROOT "agent\active_model.txt"
        $newModel | Out-File -FilePath $modelConf -Encoding UTF8
        Write-Host "`n$PINK[+] Switched active model to: $WHITE$newModel$RESET"
        Restart-Engine
    } else {
        Write-Host "`n$CYAN[*] Active model unchanged: $currentModel$RESET"
        Start-Sleep -Seconds 1
    }
}

# ─── ENGINE LIFECYCLE CONTROLLERS ────────────────────────────────
function Wait-ForServer($Port = 9931, $MaxWait = 35) {
    Write-Host "$CYAN[*] Booting Neural Engine (loading weights into RAM)...$RESET"
    $count = 0
    while ($count -lt $MaxWait) {
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/health" -TimeoutSec 1 -ErrorAction Stop
            if ($resp.status -eq 'ok') {
                Write-Host "`r`e[K    $GREEN[✓] Engine Ready & Online on Port $Port.$RESET"
                Start-Sleep -Milliseconds 500
                return $true
            }
        } catch { }
        Write-Host -NoNewline "`r`e[K    $PINK[*] Loading Tensor Core... ($($count)s/$($MaxWait)s)$RESET"
        Start-Sleep -Seconds 1
        $count++
    }
    Write-Host "`r`e[K    $ORANGE[!] Engine taking longer to respond.$RESET"
    return $false
}

function Stop-Engine {
    Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 500
}

function Start-Engine {
    Stop-Engine
    $activeModel = Get-ActiveModel
    $modelFile   = Join-Path $USB_ROOT "models\$activeModel"
    $serverExe   = Join-Path $USB_ROOT "bin\win-x64\llama-server.exe"
    $webUiPath   = Join-Path $USB_ROOT "agent\webui"

    if (-not (Test-Path $modelFile)) {
        Write-Host "$RED[!] Error: Model not found: $modelFile$RESET"
        return
    }

    if (Test-Path $serverExe) {
        Start-Process -FilePath $serverExe -ArgumentList "-m `"$modelFile`" -c 4096 --host 0.0.0.0 --port 9931 --path `"$webUiPath`"" -WindowStyle Hidden
        Wait-ForServer -Port 9931 -MaxWait 35
    } else {
        Write-Host "$RED[!] Error: llama-server.exe binary not found at $serverExe$RESET"
    }
}

function Restart-Engine {
    Start-Engine
}

# ─── CUSTOM SKILL / TOOL REGISTRY MANAGEMENT ─────────────────────
function Get-SkillsManifest {
    $skillsDir = Join-Path $USB_ROOT "agent\skills"
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
    $skillsDir = Join-Path $USB_ROOT "agent\skills"
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

# ─── CUSTOM SKILL / TOOL REGISTRY MANAGEMENT ─────────────────────
function Execute-CustomSkillMenu {
    $skillsDir = Join-Path $USB_ROOT "agent\skills"
    if (-not (Test-Path $skillsDir)) {
        New-Item -ItemType Directory -Path $skillsDir -Force > $null
    }

    while ($true) {
        Draw-Banner
        Write-Host "$PINK[WARSTICK CUSTOM SKILLS & MODULAR EXTENSIONS]$RESET`n"

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
            Write-Host "  $ORANGE[!] No skill scripts discovered inside agent\skills\$RESET"
            Write-Host "      $WHITEDrop any .ps1, .py, or .sh files into agent\skills\ to load them dynamically.$RESET`n"
        }

        Write-Host "`n  $PINK[+]$RESET Create New Modular Skill Script Template"
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

            Write-Host "`n$GREEN[✓] Skill script template created at: ${WHITE}agent\skills\${slug}.ps1$RESET"
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

            $logsDir = Join-Path $USB_ROOT "agent\logs"
            if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force > $null }

            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $sessionLog = Join-Path $logsDir "skill_${timestamp}.txt"
            $masterLog  = Join-Path $USB_ROOT "agent\agent_log.txt"

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
            Write-Host "$CYAN[*] Log saved to: ${WHITE}agent\logs\skill_${timestamp}.txt$RESET"
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

    $currentPhrase = $phrases[(Get-Random -Maximum $phrases.Count)]
    Write-Host "$CYAN[*] Initializing Neural Bus...$RESET"

    $job = Start-Job -ScriptBlock {
        param($body)
        try {
            $resp = Invoke-RestMethod -Uri "http://127.0.0.1:9931/v1/chat/completions" -Method Post -Body $body -ContentType "application/json" -TimeoutSec 120
            return ($resp | ConvertTo-Json -Depth 10 -Compress)
        } catch {
            return $_.Exception.Message
        }
    } -ArgumentList $Payload

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

        Write-Host -NoNewline "`r`e[K    $c1[$g1$c2$g2$c1]$RESET $currentPhrase $WHITE$($hz)Hz$RESET "
        Start-Sleep -Milliseconds 120
    }

    $raw = Receive-Job -Job $job
    Remove-Job -Job $job -Force > $null
    Write-Host "`r`e[K    $CYAN[✓] Neural Synthesis Complete.$RESET"
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
