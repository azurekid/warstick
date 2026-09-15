param(
    [Parameter(Mandatory = $true)]
    [string]$USB_ROOT
)

$global:USB_ROOT = $USB_ROOT
$env:USB_ROOT = $USB_ROOT

# ─── LOAD CENTRALIZED UI & RUNTIME HELPERS ──────────────────────
. "$USB_ROOT\command-core\lib\ui_common.ps1"

# ─── BACKGROUND ENGINE INITIALIZATION (WINDOWS) ─────────────────
Start-Engine
Start-HistoryServer | Out-Null
Start-ImageServer | Out-Null

while ($true) {
    Draw-Banner
    $activeM = Get-ActiveModel
    Write-Host "$PINK[WARSTICK COMMAND CONSOLE]$RESET $CYAN// ACTIVE MODEL:$RESET $WHITE$activeM$RESET"
    Write-Host "  [1] Display Prepared Exploit & Recon Prompts"
    Write-Host "  [2] Select and Execute Attack Vector (Multi-Step Chaining)"
    Write-Host "  [3] Manually Input Custom Offensive Objective"
    Write-Host "  [4] Tactical Modules & External OSINT Lookups"
    Write-Host "  [5] Select / Download LLM Model"
    Write-Host "  [6] Open Interactive Web UI Dashboard"
    Write-Host "  [7] View Local Red-Team Audit Logs"
    Write-Host "  [8] Terminate WarStick Runtime & Purge Memory"
    Write-Host ""
    Write-Host -NoNewline "$PINKwarstick@command-console:~# $RESET"
    $choice = Read-Host

    switch ($choice) {
        "1" {
            Stop-ImageServer
            Draw-Banner
            Write-Host "$CYAN─── [EXPLOIT & RECON VECTORS] ──────────────────────────$RESET`n"
            $promptsFile = "$USB_ROOT\command-core\prompts.txt"
            if (Test-Path $promptsFile) {
                Get-Content $promptsFile
            } else {
                Write-Host "$ORANGE[!] Run option 2 first to seed database structure.$RESET"
            }
            Write-Host "`n$PINK───────────────────────────────────────────────────────$RESET"
            Read-Host "Press [Enter] to cycle back to matrix..."
        }
        "2" {
            Draw-Banner
            $promptsFile = "$USB_ROOT\command-core\prompts.txt"
            if (-not (Test-Path $promptsFile)) {
                New-Item -ItemType Directory -Path "$USB_ROOT\command-core" -Force > $null
                @(
                    "[1] Host Recon: Enumerate network interface adapters, local routing metrics, and scan for active listeners on 22 or 445.",
                    "[2] PrivEsc Audit: Check user assignment privileges, environment fields, and look for misconfigured system binaries.",
                    "[3] Security Audit: Inspect host native packet firewall status profiles and review security update histories.",
                    "[4] Persistence Check: Identify cron configurations, background daemons, and tasks loaded at boot initialization."
                ) | Out-File -FilePath $promptsFile -Encoding UTF8
            }

            Write-Host "$CYAN─── [EXPLOIT & RECON VECTORS] ──────────────────────────$RESET`n"
            Get-Content $promptsFile
            Write-Host ""
            Write-Host -NoNewline "$ORANGESelect target attack vector (1-4): $RESET"
            $num = Read-Host

            $matchedLine = (Get-Content $promptsFile | Where-Object { $_ -match "\[$num\]" })
            if (-not $matchedLine) {
                Write-Host "$RED[!] Error: Invalid matrix vector assignment.$RESET"
                Start-Sleep -Seconds 1.5
                continue
            }

            $userTask = $matchedLine -replace "\[$num\]\s*", ""
            Draw-Banner
            Write-Host "$PINK[!] VECTOR UNLOCKED ->$RESET $WHITE$userTask$RESET`n"

            $logsDir = Join-Path $USB_ROOT "warstick-logs"
            if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force > $null }

            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $sessionLog = Join-Path $logsDir "audit_${timestamp}.txt"
            $masterLog  = Join-Path $USB_ROOT "warstick-logs\warstick.log"

            $sessionHeader = "===============================================================================`r`n[WARSTICK AUDIT SESSION - $timestamp]`r`nHost Platform : Windows (PowerShell)`r`nTarget Vector : $userTask`r`n==============================================================================="
            $sessionHeader | Out-File -FilePath $sessionLog -Encoding UTF8
            "`r`n$sessionHeader" | Out-File -FilePath $masterLog -Append -Encoding UTF8

            $currentContext = "Host operating system is Windows. The primary objective is: $userTask. Output native Windows PowerShell / cmd utilities only."

            $cycleSteps = @()
            $cycleCommands = @()
            $cycleStatuses = @()

            for ($step = 1; $step -le 3; $step++) {
                Write-Host "`n$PURPLE─── OPERATIONAL CYCLE $step OF 3 ───────────────────────────$RESET"

                $payload = @{
                    messages = @(
                        @{ role = "system"; content = "You are an autonomous tactical offensive security engine targeting Windows. Output ONLY the single exact executable PowerShell or Windows cmd utility (e.g., Get-NetIPAddress, netstat, Get-Process, ipconfig, tasklist, qprocess, reg query, Invoke-RestMethod, curl.exe, Select-String) to advance toward the objective. Do NOT assume Python is installed. Use native Windows PowerShell/cmd utilities. Do not think, explain, or discuss. Output ONLY the raw command string." },
                        @{ role = "user"; content = $currentContext }
                    )
                    temperature = 0.1
                    max_tokens = 512
                } | ConvertTo-Json -Depth 5

                $rawResponse = Query-LlmWithAnimation -Payload $payload
                $execCommand = Clean-JsonCommand $rawResponse

                if ([string]::IsNullOrWhiteSpace($execCommand) -or $execCommand -match "STOP") {
                    Write-Host "$CYAN[*] Vector fully optimized. Closing operational loop.$RESET"
                    $cycleSteps += $step
                    $cycleCommands += "OPTIMIZED / STOPPED"
                    $cycleStatuses += "COMPLETED"
                    break
                }

                if ($execCommand -match "^REFUSAL:") {
                    $refusalMsg = $execCommand -replace "^REFUSAL:\s*", ""
                    Write-Host "`n$RED[!] MODEL REFUSAL / SAFETY INTERCEPT:$RESET"
                    Write-Host "$ORANGE$refusalMsg$RESET"
                    $cycleSteps += $step
                    $cycleCommands += "REFUSAL: $refusalMsg"
                    $cycleStatuses += "REFUSED"
                    "`r`n[REFUSAL] $refusalMsg" | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                    "`r`n[REFUSAL] $refusalMsg" | Out-File -FilePath $masterLog -Append -Encoding UTF8
                    break
                }

                if ($execCommand -match "^ERROR:") {
                    $errorMsg = $execCommand -replace "^ERROR:\s*", ""
                    Write-Host "`n$RED[!] INFERENCE ENGINE ERROR:$RESET"
                    Write-Host "$ORANGE$errorMsg$RESET"
                    $cycleSteps += $step
                    $cycleCommands += "ERROR: $errorMsg"
                    $cycleStatuses += "FAILED"
                    "`r`n[ERROR] $errorMsg" | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                    "`r`n[ERROR] $errorMsg" | Out-File -FilePath $masterLog -Append -Encoding UTF8
                    break
                }

                if (-not (Test-PowerShellCommandSyntax -CommandText $execCommand)) {
                    $syntaxError = "Generated command is syntactically incomplete and was not executed: $execCommand"
                    Write-Host "`n$RED[!] GENERATED COMMAND REJECTED:$RESET"
                    Write-Host "$ORANGE$syntaxError$RESET"
                    $cycleSteps += $step
                    $cycleCommands += $execCommand
                    $cycleStatuses += "INVALID SYNTAX"
                    "`r`n[ERROR] $syntaxError" | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                    "`r`n[ERROR] $syntaxError" | Out-File -FilePath $masterLog -Append -Encoding UTF8
                    break
                }

                Write-Host "$PINK[>] Executing Shell Payload: $RESET$WHITE$execCommand$RESET"
                
                $cycleEntry = "`r`n-------------------------------------------------------------------------------`r`n[CYCLE $step / 3] $(Get-Date -Format 'HH:mm:ss')`r`nCommand Selected : $execCommand`r`n-------------------------------------------------------------------------------`r`n[RAW OUTPUT STREAM]`r`n"
                $cycleEntry | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                $cycleEntry | Out-File -FilePath $masterLog -Append -Encoding UTF8

                Write-Host "`n$CYAN--- SYSTEM DATA INBOUND ---$RESET"
                try {
                    $cmdOutput = (Invoke-Expression $execCommand 2>&1 | Out-String)
                } catch {
                    $cmdOutput = $_.Exception.Message
                }
                Write-Host $cmdOutput
                $cmdOutput | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                $cmdOutput | Out-File -FilePath $masterLog -Append -Encoding UTF8

                $cycleSteps += $step
                $cycleCommands += $execCommand
                $cycleStatuses += "EXECUTED"

                $cleanOutput = ($cmdOutput -replace '"', '' -replace "`r`n", " ").Substring(0, [Math]::Min(1000, $cmdOutput.Length))
                $currentContext = "Host OS is Windows. Objective: $userTask. Previous command was '$execCommand' which returned: $cleanOutput. Determine the next optimal native Windows utility step."
            }

            # Summary block
            $summaryBlock = "`r`n===============================================================================`r`n[EXECUTIVE AUDIT SUMMARY]`r`nTarget Objective: $userTask`r`nTotal Cycles Executed: $($cycleSteps.Count)`r`n"
            for ($i = 0; $i -lt $cycleSteps.Count; $i++) {
                $summaryBlock += "`r`n  Cycle $($cycleSteps[$i]) [$($cycleStatuses[$i])]: $($cycleCommands[$i])"
            }
            $summaryBlock += "`r`n===============================================================================`r`n"

            $summaryBlock | Out-File -FilePath $sessionLog -Append -Encoding UTF8
            $summaryBlock | Out-File -FilePath $masterLog -Append -Encoding UTF8

            Write-Host "`n$GREEN[✓] Run complete.$RESET"
            Write-Host "$CYAN[*] Session log saved to: ${WHITE}warstick-logs\audit_${timestamp}.txt$RESET"
            Write-Host "$CYAN[*] Master log appended: ${WHITE}warstick-logs\warstick.log$RESET"
            Read-Host "Press [Enter] to refresh terminal environment..."
        }
        "3" {
            Draw-Banner
            Write-Host "${CYAN}Tip: You can call skills directly like: $WHITE/geo_ip_lookup 8.8.8.8$CYAN or $WHITE/url_intelligence https://site.com$RESET"
            Write-Host "${CYAN}Enter another prompt after each result. Submit a blank prompt or $WHITE/back$CYAN to return.$RESET"
            while ($true) {
                Write-Host -NoNewline "$ORANGEEnter Custom Attack Parameters: $RESET"
                $customTask = Read-Host

                if ([string]::IsNullOrWhiteSpace($customTask) -or $customTask -eq '/back') {
                    break
                }

            Draw-Banner
            $logsDir = Join-Path $USB_ROOT "warstick-logs"
            if (-not (Test-Path $logsDir)) { New-Item -ItemType Directory -Path $logsDir -Force > $null }

            $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
            $sessionLog = Join-Path $logsDir "custom_${timestamp}.txt"
            $masterLog  = Join-Path $USB_ROOT "warstick-logs\warstick.log"

            $sessionHeader = "===============================================================================`r`n[WARSTICK CUSTOM MISSION - $timestamp]`r`nHost Platform : Windows (PowerShell)`r`nObjective     : $customTask`r`n==============================================================================="
            $sessionHeader | Out-File -FilePath $sessionLog -Encoding UTF8
            "`r`n$sessionHeader" | Out-File -FilePath $masterLog -Append -Encoding UTF8

            # Check if user referenced a skill directly
            $directSkillCmd = Try-DirectSkillExecution -userInput $customTask

            if ($directSkillCmd) {
                $execCommand = $directSkillCmd
                Write-Host "$PINK[!] Direct Skill Trigger Detected: $WHITE$execCommand$RESET"
            } else {
                $skillsManifest = Get-SkillsManifest
                $payload = @{
                    messages = @(
                        @{ role = "system"; content = "You are a terminal command utility mapping engine for Windows. Output ONLY the single exact executable PowerShell or Windows cmd command string to resolve the prompt target parameter. WarStick local ports are: main LLM and Web UI 9931, history 9932, image generation 9933. For the local WarStick service or local AI engine, use http://127.0.0.1:9931 unless the user explicitly supplies another port; never invent port 8080. Available tactical modules: $skillsManifest. You may invoke a tactical module via `& `"$USB_ROOT\tactics\<script>`" -Target `<arg>` if matching. Do NOT assume Python is installed. Use native PowerShell (Invoke-RestMethod, ConvertFrom-Json, Select-Object) or CMD utilities. Do not think, explain, or discuss. No markdown, raw command line only." },
                        @{ role = "user"; content = $customTask }
                    )
                    temperature = 0.1
                    max_tokens = 512
                } | ConvertTo-Json -Depth 5

                $rawResponse = Query-LlmWithAnimation -Payload $payload
                $execCommand = Clean-JsonCommand $rawResponse
            }

            if ($execCommand -match "^REFUSAL:") {
                $refusalMsg = $execCommand -replace "^REFUSAL:\s*", ""
                Write-Host "`n$RED[!] MODEL REFUSAL / SAFETY INTERCEPT:$RESET"
                Write-Host "$ORANGE$refusalMsg$RESET"
                "`r`n-------------------------------------------------------------------------------`r`n[REFUSAL] $(Get-Date -Format 'HH:mm:ss')`r`n$refusalMsg`r`n===============================================================================" | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                "`r`n-------------------------------------------------------------------------------`r`n[REFUSAL] $(Get-Date -Format 'HH:mm:ss')`r`n$refusalMsg`r`n===============================================================================" | Out-File -FilePath $masterLog -Append -Encoding UTF8
            } elseif ($execCommand -match "^TEMPLATE:") {
                $templatePayload = $execCommand -replace "^TEMPLATE:\s*", ""
                Write-Host "`n$ORANGE[!] PARAMETER TEMPLATE GENERATED (Requires User Input):$RESET"
                Write-Host "    $WHITE$templatePayload$RESET"
                Write-Host "`n$CYAN[*] Replace placeholders (e.g. <target_ip>) with your specific environment target values.$RESET"
                "`r`n-------------------------------------------------------------------------------`r`n[TEMPLATE] $(Get-Date -Format 'HH:mm:ss')`r`nCommand Template : $templatePayload`r`nStatus           : REQUIRES_TARGET_INPUT`r`n===============================================================================" | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                "`r`n-------------------------------------------------------------------------------`r`n[TEMPLATE] $(Get-Date -Format 'HH:mm:ss')`r`nCommand Template : $templatePayload`r`nStatus           : REQUIRES_TARGET_INPUT`r`n===============================================================================" | Out-File -FilePath $masterLog -Append -Encoding UTF8
            } elseif ($execCommand -match "^ERROR:") {
                $errorMsg = $execCommand -replace "^ERROR:\s*", ""
                Write-Host "`n$RED[!] INFERENCE ENGINE ERROR:$RESET"
                Write-Host "$ORANGE$errorMsg$RESET"
                "`r`n-------------------------------------------------------------------------------`r`n[ERROR] $(Get-Date -Format 'HH:mm:ss')`r`n$errorMsg`r`n===============================================================================" | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                "`r`n-------------------------------------------------------------------------------`r`n[ERROR] $(Get-Date -Format 'HH:mm:ss')`r`n$errorMsg`r`n===============================================================================" | Out-File -FilePath $masterLog -Append -Encoding UTF8
            } elseif (-not (Test-PowerShellCommandSyntax -CommandText $execCommand)) {
                $syntaxError = "Generated command is syntactically incomplete and was not executed: $execCommand"
                Write-Host "`n$RED[!] GENERATED COMMAND REJECTED:$RESET"
                Write-Host "$ORANGE$syntaxError$RESET"
                "`r`n-------------------------------------------------------------------------------`r`n[ERROR] $(Get-Date -Format 'HH:mm:ss')`r`n$syntaxError`r`n===============================================================================" | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                "`r`n-------------------------------------------------------------------------------`r`n[ERROR] $(Get-Date -Format 'HH:mm:ss')`r`n$syntaxError`r`n===============================================================================" | Out-File -FilePath $masterLog -Append -Encoding UTF8
            } else {
                Write-Host "$PINK[>] Executing Custom Payload: $RESET$WHITE$execCommand$RESET"
                
                $cmdHeader = "`r`n-------------------------------------------------------------------------------`r`n[MISSION STEP] $(Get-Date -Format 'HH:mm:ss')`r`nCommand Selected : $execCommand`r`n-------------------------------------------------------------------------------`r`n[RAW OUTPUT STREAM]`r`n"
                $cmdHeader | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                $cmdHeader | Out-File -FilePath $masterLog -Append -Encoding UTF8

                Write-Host "`n$CYAN--- RUNTIME OUTPUT STREAM ---$RESET"
                try {
                    $cmdOutput = (Invoke-Expression $execCommand 2>&1 | Out-String)
                } catch {
                    $cmdOutput = $_.Exception.Message
                }
                Write-Host $cmdOutput
                $cmdOutput | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                $cmdOutput | Out-File -FilePath $masterLog -Append -Encoding UTF8

                $summaryBlock = "`r`n===============================================================================`r`n[MISSION OUTCOME]`r`nObjective : $customTask`r`nCommand   : $execCommand`r`nStatus    : EXECUTED`r`n===============================================================================`r`n"
                $summaryBlock | Out-File -FilePath $sessionLog -Append -Encoding UTF8
                $summaryBlock | Out-File -FilePath $masterLog -Append -Encoding UTF8
            }

            Write-Host "`n$GREEN[✓] Execution complete.$RESET"
            Write-Host "$CYAN[*] Log saved to: ${WHITE}warstick-logs\custom_${timestamp}.txt$RESET"
            Write-Host "`n$PINK───────────────────────────────────────────────────────$RESET"
            }
        }
        "4" {
            Execute-CustomSkillMenu
        }
        "5" {
            Select-ModelMenu
        }
        "6" {
            Write-Host "$GREEN[*] Injecting browser GUI pipeline...$RESET"
            Start-Process "http://127.0.0.1:9931"
            Start-Sleep -Seconds 1
        }
        "7" {
            Draw-Banner
            Write-Host "$CYAN─── [HISTORICAL AUDIT STREAM LOGS] ────────────────────$RESET`n"
            $logsDir = Join-Path $USB_ROOT "warstick-logs"
            $masterLog = Join-Path $USB_ROOT "warstick-logs\warstick.log"

            if (Test-Path $logsDir) {
                $recentFiles = Get-ChildItem $logsDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 10
                if ($recentFiles) {
                    Write-Host "$WHITEAvailable Session Logs:$RESET"
                    $recentFiles | ForEach-Object { Write-Host "  $($_.Name)" }
                    Write-Host "`n$PINK--- Displaying Latest Audit Stream ---$RESET`n"
                    Get-Content $recentFiles[0].FullName
                }
            } elseif (Test-Path $masterLog) {
                Get-Content $masterLog
            } else {
                Write-Host "$ORANGE[!] Empty buffer. No current transaction loops mapped.$RESET"
            }
            Write-Host "`n$CYAN───────────────────────────────────────────────────────$RESET"
            Read-Host "Press [Enter] to slice back to matrix..."
        }
        "8" {
            Clear-Host
            Write-Host "$PINK[!] PURGING WARSTICK SYSTEM INFRASTRUCTURE...$RESET"
            Stop-HistoryServer
            Stop-Engine
            Start-Sleep -Milliseconds 500
            Write-Host "$CYAN[✓] Volatile Cache Dropped. Terminal offline.$RESET"
            exit 0
        }
        Default {
            Write-Host "$RED[!] Command entry unrecognized.$RESET"
            Start-Sleep -Seconds 1
        }
    }
}
