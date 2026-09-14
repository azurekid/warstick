# Setup-only backend detection and installation helpers.
function Get-RecommendedBackendVariant {
    $gpus = @()
    try {
        $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction Stop)
    } catch { }

    $hasNvidia = @($gpus | Where-Object { $_.Name -match 'NVIDIA' }).Count -gt 0
    $nvidiaSmi = Get-Command nvidia-smi.exe -ErrorAction SilentlyContinue
    if ($hasNvidia -and $nvidiaSmi) {
        $driverText = & $nvidiaSmi.Path --query-gpu=driver_version --format=csv,noheader 2> $null | Select-Object -First 1
        $driverVersion = $null
        if ($LASTEXITCODE -eq 0 -and [version]::TryParse(($driverText -split '\s+')[0], [ref]$driverVersion) -and $driverVersion -ge [version]'551.61') {
            return 'cuda'
        }
    }

    $hardwareGpus = @($gpus | Where-Object {
        $_.Name -and $_.Name -notmatch 'Microsoft Basic|Remote Display|Virtual|Indirect Display'
    })
    $vulkanLoader = if ($env:WINDIR) { Join-Path $env:WINDIR 'System32\vulkan-1.dll' } else { $null }
    if ($hardwareGpus.Count -gt 0 -and $vulkanLoader -and (Test-Path $vulkanLoader)) { return 'vulkan' }
    return 'cpu'
}

function Get-InstalledBackendVariant($Directory) {
    $server = Join-Path $Directory 'llama-server.exe'
    $coreLibrary = Join-Path $Directory 'ggml.dll'
    if (-not (Test-Path $server) -or -not (Test-Path $coreLibrary)) { return 'unknown' }

    $marker = Join-Path $Directory '.backend-variant'
    if (Test-Path $marker) { return (Get-Content $marker -Raw).Trim() }
    if (Get-ChildItem -Path $Directory -Filter 'ggml-cuda*.dll' -ErrorAction SilentlyContinue) { return 'cuda' }
    if (Get-ChildItem -Path $Directory -Filter 'ggml-vulkan*.dll' -ErrorAction SilentlyContinue) { return 'vulkan' }
    return 'cpu'
}

function Save-SetupDownload([string]$Url, [string]$TargetPath, [string]$Label) {
    if (Test-Path -LiteralPath $TargetPath -PathType Leaf) {
        Write-Host "$GREEN[✓] $Label already exists.$RESET"
        return $true
    }

    $parent = Split-Path -Parent $TargetPath
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
    $partialPath = "$TargetPath.part"
    Write-Host "$CYAN[>>] Downloading $Label...$RESET"
    try {
        $headers = @{}
        $hfAccessToken = if ($env:HF_TOKEN) { $env:HF_TOKEN } else { $env:HUGGING_FACE_HUB_TOKEN }
        if ($Url.StartsWith('https://huggingface.co/') -and $hfAccessToken) {
            $headers.Authorization = "Bearer $hfAccessToken"
        }
        Invoke-WebRequest -Uri $Url -OutFile $partialPath -Headers $headers -UseBasicParsing
        Move-Item -LiteralPath $partialPath -Destination $TargetPath -Force
        return $true
    } catch {
        Remove-Item -LiteralPath $partialPath -Force -ErrorAction SilentlyContinue
        Write-Host "$RED[!] Download failed: $($_.Exception.Message)$RESET"
        return $false
    }
}

function Get-SdReleaseAsset([string]$Pattern) {
    try {
        $headers = @{ Accept = 'application/vnd.github+json'; 'User-Agent' = 'WarStick-Setup' }
        $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/leejet/stable-diffusion.cpp/releases/latest' -Headers $headers -UseBasicParsing
        return $release.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
    } catch {
        Write-Host "$RED[!] Could not query the latest stable-diffusion.cpp release: $($_.Exception.Message)$RESET"
        return $null
    }
}

function Install-ZImageTurbo([string]$BackendVariant) {
    Write-Host "`n$PINK─── [OPTIONAL Z-IMAGE TURBO // IMAGE GENERATION] ───────────────$RESET"
    Write-Host "$CYAN    Requires about 6 GB of downloads and 7 GB of free storage.$RESET"
    $answer = Read-Host "$ORANGE[?] Install the native image engine and model bundle? [y/N]$RESET"
    if ($answer -notmatch '^[Yy]$') { return }

    $assetPattern = switch ($BackendVariant) {
        'cuda' { '-bin-win-cuda12-x64\.zip$' }
        'vulkan' { '-bin-win-vulkan-x64\.zip$' }
        default { '-bin-win-cpu-x64\.zip$' }
    }
    $destDir = Join-Path $USB_ROOT 'bin\win-x64\image'
    $sdBinary = Get-ChildItem -Path $destDir -Filter 'sd-cli.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $sdBinary) {
        $archivePath = Join-Path $USB_ROOT 'bin\image-backend.zip'
        Write-Host "$CYAN[*] Resolving the latest stable-diffusion.cpp release...$RESET"
        $asset = Get-SdReleaseAsset $assetPattern
        if (-not $asset) {
            Write-Host "$RED[!] No compatible image-engine asset was found in the latest release.$RESET"
            return
        }
        if (-not (Save-SetupDownload $asset.browser_download_url $archivePath $asset.name)) { return }
        try {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            Expand-Archive -LiteralPath $archivePath -DestinationPath $destDir -Force
            if ($BackendVariant -eq 'cuda') {
                $cudaRuntime = Get-SdReleaseAsset '^cudart-sd-bin-win-cu12-x64\.zip$'
                if (-not $cudaRuntime) { throw 'The matching CUDA runtime asset was not found.' }
                $cudaArchivePath = Join-Path $USB_ROOT 'bin\image-cudart.zip'
                if (-not (Save-SetupDownload $cudaRuntime.browser_download_url $cudaArchivePath $cudaRuntime.name)) {
                    throw 'The CUDA runtime download failed.'
                }
                Expand-Archive -LiteralPath $cudaArchivePath -DestinationPath $destDir -Force
            }
        } catch {
            Write-Host "$RED[!] Could not extract the image engine: $($_.Exception.Message)$RESET"
            return
        } finally {
            Remove-Item -LiteralPath $archivePath, $cudaArchivePath -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "$GREEN[✓] Native image engine already exists.$RESET"
    }

    $modelDir = Join-Path $USB_ROOT 'models\image\z-image-turbo'
    $downloads = @(
        @('https://huggingface.co/leejet/Z-Image-Turbo-GGUF/resolve/main/z_image_turbo-Q3_K.gguf', (Join-Path $modelDir 'z_image_turbo-Q3_K.gguf'), 'Z-Image Turbo Q3_K diffusion model'),
        @('https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors', (Join-Path $modelDir 'ae.safetensors'), 'Z-Image VAE'),
        @('https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf', (Join-Path $modelDir 'Qwen3-4B-Instruct-2507-Q4_K_M.gguf'), 'Qwen3 4B Q4_K_M text encoder')
    )
    foreach ($download in $downloads) {
        if (-not (Save-SetupDownload $download[0] $download[1] $download[2])) { return }
    }
    Write-Host "$GREEN[✓] Z-Image Turbo is ready. Generated images will be stored on this drive.$RESET"
}

function Install-FluxSchnell {
    Write-Host "`n$PINK─── [OPTIONAL FLUX.1 SCHNELL // IMAGE GENERATION] ─────────────────$RESET"
    Write-Host "$CYAN    Requires about 11 GB of downloads and 12 GB of free storage.$RESET"
    $answer = Read-Host "$ORANGE[?] Install the FLUX.1 Schnell Q3_K_M model bundle? [y/N]$RESET"
    if ($answer -notmatch '^[Yy]$') { return }

    $modelDir = Join-Path $USB_ROOT 'models\image\flux1-schnell'
    $hfAccessToken = if ($env:HF_TOKEN) { $env:HF_TOKEN } else { $env:HUGGING_FACE_HUB_TOKEN }
    if (-not (Test-Path (Join-Path $modelDir 'ae.safetensors')) -and -not $hfAccessToken) {
        Write-Host "$ORANGE[!] FLUX.1 Schnell requires access to its gated VAE on Hugging Face.$RESET"
        Write-Host "$WHITE    Accept the model terms, then set HF_TOKEN and rerun setup.$RESET"
        return
    }

    $sdBinary = Get-ChildItem -Path (Join-Path $USB_ROOT 'bin\win-x64\image') -Filter 'sd-cli.exe' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $sdBinary) {
        Write-Host "$ORANGE[!] Install the native image engine from the Z-Image prompt first.$RESET"
        return
    }

    $downloads = @(
        @('https://huggingface.co/unsloth/FLUX.1-schnell-GGUF/resolve/main/flux1-schnell-Q3_K_M.gguf', (Join-Path $modelDir 'flux1-schnell-Q3_K_M.gguf'), 'FLUX.1 Schnell Q3_K_M diffusion model'),
        @('https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors', (Join-Path $modelDir 'ae.safetensors'), 'FLUX.1 VAE'),
        @('https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors', (Join-Path $modelDir 'clip_l.safetensors'), 'FLUX CLIP-L text encoder'),
        @('https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors', (Join-Path $modelDir 't5xxl_fp8_e4m3fn.safetensors'), 'FLUX T5-XXL FP8 text encoder')
    )
    foreach ($download in $downloads) {
        if (-not (Save-SetupDownload $download[0] $download[1] $download[2])) { return }
    }
    Write-Host "$GREEN[✓] FLUX.1 Schnell is ready and will appear in the Image model selector.$RESET"
}

function Initialize-WarStickSetup {
    Draw-Banner
    Write-Host "$PINK─── [WARSTICK SETUP MATRIX // UNCENSORED STUDIO ENGINE] ────────────$RESET`n"

    $backendVariant = Get-RecommendedBackendVariant
    $destDir = Join-Path $USB_ROOT "bin\win-x64"
    $installedVariant = Get-InstalledBackendVariant $destDir
    Write-Host "$CYAN[*] Selected $WHITE$backendVariant$CYAN backend for detected hardware.$RESET"

    $serverExe = Get-EngineBinary
    if (-not $serverExe -or -not (Test-Path $serverExe) -or $installedVariant -ne $backendVariant) {
        Write-Host "$CYAN[*] Preparing $backendVariant llama.cpp backend...$RESET"
        if ($installedVariant -ne 'unknown' -and $installedVariant -ne $backendVariant) {
            Write-Host "$ORANGE[*] Replacing $installedVariant backend with $backendVariant.$RESET"
        }

        Write-Host "$CYAN[*] Downloading self-contained Uncensored Studio llama.cpp release...$RESET"
        $release = "b9668"
        New-Item -ItemType Directory -Force -Path $destDir | Out-Null

        $assetName = switch ($backendVariant) {
            'cuda' { "llama-$release-bin-win-cuda-12.4-x64.zip" }
            'vulkan' { "llama-$release-bin-win-vulkan-x64.zip" }
            default { "llama-$release-bin-win-cpu-x64.zip" }
        }
        $archiveUrl = "https://github.com/ggml-org/llama.cpp/releases/download/$release/$assetName"
        $archivePath = Join-Path $USB_ROOT "bin\backend.zip"
        $cudaArchivePath = Join-Path $USB_ROOT "bin\backend-cudart.zip"

        Write-Host "$CYAN[>>] Downloading $assetName...$RESET"
        try {
            Invoke-WebRequest -Uri $archiveUrl -OutFile $archivePath -UseBasicParsing
            if ($backendVariant -eq 'cuda') {
                $cudaAssetName = "cudart-llama-bin-win-cuda-12.4-x64.zip"
                $cudaArchiveUrl = "https://github.com/ggml-org/llama.cpp/releases/download/$release/$cudaAssetName"
                Write-Host "$CYAN[>>] Downloading $cudaAssetName...$RESET"
                Invoke-WebRequest -Uri $cudaArchiveUrl -OutFile $cudaArchivePath -UseBasicParsing
            }

            Get-ChildItem -Path (Join-Path $destDir '*') -Include 'ggml-cuda*.dll','ggml-vulkan*.dll','ggml-hip*.dll','ggml-sycl*.dll','cudart64_*.dll','cublas*.dll' -File -ErrorAction SilentlyContinue | Remove-Item -Force
            Expand-Archive -Path $archivePath -DestinationPath $destDir -Force
            if ($backendVariant -eq 'cuda') {
                Expand-Archive -Path $cudaArchivePath -DestinationPath $destDir -Force
            }

            if ((Test-Path (Join-Path $destDir 'llama-server.exe')) -and (Test-Path (Join-Path $destDir 'ggml.dll'))) {
                $backendVariant | Out-File -FilePath (Join-Path $destDir '.backend-variant') -Encoding ascii
            } else {
                Write-Host "$RED[!] Backend archive did not contain a complete llama-server installation.$RESET"
            }
        } catch {
            Write-Host "$RED[!] Backend download failed: $($_.Exception.Message)$RESET"
        } finally {
            Remove-Item $archivePath, $cudaArchivePath -Force -ErrorAction SilentlyContinue
        }
        $serverExe = Get-EngineBinary
    } else {
        Write-Host "$GREEN[✓] Neural Engine backend binary is verified: $serverExe$RESET"
    }

    $discoveredModels = Get-DiscoveredModelFiles
    if ($discoveredModels.Count -eq 0) {
        Write-Host "`n$PINK[*] No GGUF models discovered in USB or Uncensored AI Studio paths.$RESET"
        Write-Host "$CYAN[>>] Downloading starter Qwen2.5-Coder model (491 MB)...$RESET"
        $modelsDir = Join-Path $USB_ROOT "models"
        New-Item -ItemType Directory -Force -Path $modelsDir | Out-Null
        $modelUrl = "https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
        $targetPath = Join-Path $modelsDir "qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
        try {
            Invoke-WebRequest -Uri $modelUrl -OutFile $targetPath -UseBasicParsing
            Write-Host "$GREEN[✓] Starter model downloaded successfully!$RESET"
        } catch {
            Write-Host "$RED[!] Model download failed: $($_.Exception.Message)$RESET"
        }
    } else {
        Write-Host "$GREEN[✓] Discovered $($discoveredModels.Count) model(s) in registry.$RESET"
    }

    Install-ZImageTurbo $backendVariant
    Install-FluxSchnell

    Write-Host "`n$GREEN[✓] WarStick Neural Setup Complete!$RESET"
    Start-Sleep -Seconds 1.5
}
