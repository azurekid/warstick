#!/bin/bash

# Setup-only backend detection and installation helpers.
detect_backend_variant() {
    local OS_TYPE="$1"

    if [ "$OS_TYPE" == "mac" ]; then
        echo "metal"
        return 0
    fi

    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
        echo "vulkan"
    elif command -v vulkaninfo >/dev/null 2>&1 && vulkaninfo --summary >/dev/null 2>&1; then
        echo "vulkan"
    elif compgen -G '/dev/dri/renderD*' >/dev/null && ldconfig -p 2>/dev/null | grep -q 'libvulkan\.so'; then
        echo "vulkan"
    else
        echo "cpu"
    fi
}

get_installed_backend_variant() {
    local DEST_DIR="$1"

    if [ -f "$DEST_DIR/llama-server" ] && [ -f "$DEST_DIR/.backend-variant" ]; then
        tr -d '\r\n' < "$DEST_DIR/.backend-variant"
    elif compgen -G "$DEST_DIR/libggml-metal*.dylib" >/dev/null; then
        echo "metal"
    elif compgen -G "$DEST_DIR/libggml-vulkan*.so*" >/dev/null; then
        echo "vulkan"
    elif [ -f "$DEST_DIR/llama-server" ] && compgen -G "$DEST_DIR/libggml-cpu*.so*" >/dev/null; then
        echo "cpu"
    else
        echo "unknown"
    fi
}

download_setup_file() {
    local URL="$1"
    local TARGET_PATH="$2"
    local LABEL="$3"

    if [ -f "$TARGET_PATH" ]; then
        echo -e "${GREEN}[✓] $LABEL already exists.${RESET}"
        return 0
    fi

    mkdir -p "$(dirname "$TARGET_PATH")"
    echo -e "${CYAN}[>>] Downloading $LABEL...${RESET}"
    local -a CURL_HEADERS=()
    local -a CURL_TRANSPORT_ARGS=(--retry 5 --retry-delay 2 --retry-all-errors --continue-at -)
    local HF_ACCESS_TOKEN="${HF_TOKEN:-${HUGGING_FACE_HUB_TOKEN:-}}"
    if [[ "$URL" == https://huggingface.co/* ]] && [ -n "$HF_ACCESS_TOKEN" ]; then
        CURL_HEADERS=(-H "Authorization: Bearer $HF_ACCESS_TOKEN")
    fi
    if [[ "$URL" == https://huggingface.co/* ]]; then
        CURL_TRANSPORT_ARGS+=(--http1.1)
    fi
    if [ -s "$TARGET_PATH.part" ]; then
        echo -e "${CYAN}[>>] Resuming $LABEL from $(du -h "$TARGET_PATH.part" | cut -f1).${RESET}"
    fi
    if curl -fL --progress-bar "${CURL_TRANSPORT_ARGS[@]}" "${CURL_HEADERS[@]}" "$URL" -o "$TARGET_PATH.part"; then
        mv -f "$TARGET_PATH.part" "$TARGET_PATH"
        return 0
    fi
    echo -e "${RED}[!] Download failed: $URL${RESET}"
    echo -e "${ORANGE}    Partial data was kept and will resume the next time setup runs.${RESET}"
    return 1
}

resolve_sd_release_asset() {
    local ASSET_PATTERN="$1"
    local PINNED_RELEASE="master-866-42d6c0a"
    local PINNED_COMMIT="42d6c0a"
    local RELEASE_API="https://api.github.com/repos/leejet/stable-diffusion.cpp/releases/latest"
    local RELEASE_JSON
    if RELEASE_JSON=$(curl -fsSL -H 'Accept: application/vnd.github+json' -H 'User-Agent: WarStick-Setup' "$RELEASE_API" 2>/dev/null); then
        printf '%s' "$RELEASE_JSON" | perl -MJSON::PP -0777 -e '
            my $pattern = shift @ARGV;
            my $release = decode_json(<STDIN>);
            for my $asset (@{$release->{assets} // []}) {
                if (($asset->{name} // q{}) =~ /$pattern/) {
                    print $asset->{browser_download_url};
                    exit 0;
                }
            }
            exit 1;
        ' -- "$ASSET_PATTERN" && return 0
    fi

    local RELEASE_URL
    local RELEASE_TAG
    local RESOLVED_ASSET=""
    if RELEASE_URL=$(curl -fsSL -o /dev/null -w '%{url_effective}' -H 'User-Agent: WarStick-Setup' \
        'https://github.com/leejet/stable-diffusion.cpp/releases/latest' 2>/dev/null); then
        RELEASE_TAG="${RELEASE_URL##*/}"
    fi
    if [ -n "$RELEASE_TAG" ]; then
        RESOLVED_ASSET=$(curl -fsSL -H 'User-Agent: WarStick-Setup' \
            "https://github.com/leejet/stable-diffusion.cpp/releases/expanded_assets/$RELEASE_TAG" 2>/dev/null | perl -0777 -e '
            my $pattern = shift @ARGV;
            my $html = <STDIN>;
            while ($html =~ m{href="(/leejet/stable-diffusion\.cpp/releases/download/[^"]+/([^/"]+))"}g) {
                my ($href, $name) = ($1, $2);
                if ($name =~ /$pattern/) {
                    print "https://github.com$href";
                    exit 0;
                }
            }
            exit 1;
        ' -- "$ASSET_PATTERN")
    fi
    if [ -n "$RESOLVED_ASSET" ]; then
        printf '%s' "$RESOLVED_ASSET"
        return 0
    fi

    local PINNED_ASSET=""
    if [[ "sd-${PINNED_COMMIT}-bin-Darwin-macOS-arm64.zip" =~ $ASSET_PATTERN ]]; then
        PINNED_ASSET="sd-master-${PINNED_COMMIT}-bin-Darwin-macOS-26.6.2-arm64.zip"
    elif [[ "sd-${PINNED_COMMIT}-bin-Linux-x86_64-vulkan.zip" =~ $ASSET_PATTERN ]]; then
        PINNED_ASSET="sd-master-${PINNED_COMMIT}-bin-Linux-Ubuntu-24.04-x86_64-vulkan.zip"
    elif [[ "sd-${PINNED_COMMIT}-bin-Linux-x86_64.zip" =~ $ASSET_PATTERN ]]; then
        PINNED_ASSET="sd-master-${PINNED_COMMIT}-bin-Linux-Ubuntu-24.04-x86_64.zip"
    fi
    [ -n "$PINNED_ASSET" ] || return 1
    printf 'https://github.com/leejet/stable-diffusion.cpp/releases/download/%s/%s' "$PINNED_RELEASE" "$PINNED_ASSET"
}

install_z_image_turbo() {
    local OS_TYPE="$1"
    local BACKEND_VARIANT="$2"
    local ANSWER
    echo -e "\n${PINK}─── [OPTIONAL Z-IMAGE TURBO // IMAGE GENERATION] ───────────────${RESET}"
    echo -e "${CYAN}    Requires about 6 GB of downloads and 7 GB of free storage.${RESET}"
    echo -ne "${ORANGE}[?] Install the native image engine and model bundle? [y/N]: ${RESET}"
    read -r ANSWER
    [[ "$ANSWER" =~ ^[Yy]$ ]] || return 0

    local DEST_DIR="$USB_ROOT/bin/linux-x64/image"
    local ASSET_PATTERN='-bin-Linux-.*-x86_64\.zip$'
    local IMAGE_BACKEND="$BACKEND_VARIANT"
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
        IMAGE_BACKEND="cuda"
    fi
    if [ "$IMAGE_BACKEND" == "vulkan" ] || [ "$IMAGE_BACKEND" == "cuda" ]; then
        ASSET_PATTERN="-bin-Linux-.*-x86_64-${IMAGE_BACKEND}[^/]*\\.zip$"
    fi
    if [ "$OS_TYPE" == "mac" ]; then
        if [ "$(uname -m)" != "arm64" ]; then
            echo -e "${ORANGE}[!] Z-Image Turbo prebuilt binaries currently require Apple Silicon on macOS.${RESET}"
            return 0
        fi
        DEST_DIR="$USB_ROOT/bin/mac-arm64/image"
        ASSET_PATTERN='-bin-Darwin-.*-arm64\.zip$'
    fi

    local ARCHIVE_PATH="$USB_ROOT/bin/image-backend.zip"
    local ARCHIVE_URL
    local ASSET_NAME
    mkdir -p "$DEST_DIR"
    if ! find "$DEST_DIR" -type f -name 'sd-cli' -print -quit 2>/dev/null | grep -q .; then
        if ! command -v unzip >/dev/null 2>&1; then
            echo -e "${RED}[!] The native 'unzip' utility is required to install the image engine.${RESET}"
            return 1
        fi
        echo -e "${CYAN}[*] Resolving the latest stable-diffusion.cpp release...${RESET}"
        ARCHIVE_URL=$(resolve_sd_release_asset "$ASSET_PATTERN")
        if [ -z "$ARCHIVE_URL" ] && [ "$OS_TYPE" == "linux" ] && [ "$IMAGE_BACKEND" == "cuda" ]; then
            echo -e "${ORANGE}[*] No CUDA image build is published in the latest release; trying Vulkan.${RESET}"
            ASSET_PATTERN='-bin-Linux-.*-x86_64-vulkan\.zip$'
            ARCHIVE_URL=$(resolve_sd_release_asset "$ASSET_PATTERN")
        fi
        if [ -z "$ARCHIVE_URL" ]; then
            echo -e "${RED}[!] No compatible image-engine asset was found in the latest release.${RESET}"
            return 1
        fi
        ASSET_NAME="${ARCHIVE_URL##*/}"
        download_setup_file "$ARCHIVE_URL" "$ARCHIVE_PATH" "$ASSET_NAME" || return 1
        unzip -oq "$ARCHIVE_PATH" -d "$DEST_DIR" || {
            echo -e "${RED}[!] Could not extract the image engine archive.${RESET}"
            return 1
        }
        rm -f "$ARCHIVE_PATH"
        chmod +x "$DEST_DIR"/**/sd-cli "$DEST_DIR"/sd-cli 2>/dev/null || true
    else
        echo -e "${GREEN}[✓] Native image engine already exists.${RESET}"
    fi

    local MODEL_DIR="$USB_ROOT/models/image/z-image-turbo"
    download_setup_file \
        "https://huggingface.co/leejet/Z-Image-Turbo-GGUF/resolve/main/z_image_turbo-Q3_K.gguf" \
        "$MODEL_DIR/z_image_turbo-Q3_K.gguf" "Z-Image Turbo Q3_K diffusion model" || return 1
    download_setup_file \
        "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
        "$MODEL_DIR/ae.safetensors" "Z-Image VAE" || return 1
    download_setup_file \
        "https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf" \
        "$MODEL_DIR/Qwen3-4B-Instruct-2507-Q4_K_M.gguf" "Qwen3 4B Q4_K_M text encoder" || return 1

    echo -e "${GREEN}[✓] Z-Image Turbo is ready. Generated images will be stored on this drive.${RESET}"
}

initialize_warstick_setup() {
    draw_banner
    echo -e "${PINK}─── [WARSTICK SETUP ] ────────────${RESET}\n"

    local OS_TYPE="mac"
    if [[ "$(uname -s)" == "Linux" ]]; then
        OS_TYPE="linux"
    fi

    local BACKEND_VARIANT
    local DEST_DIR
    local INSTALLED_VARIANT
    local SERVER_BIN
    BACKEND_VARIANT=$(detect_backend_variant "$OS_TYPE")
    DEST_DIR="$USB_ROOT/bin/linux-x64"
    if [ "$OS_TYPE" == "mac" ]; then
        local MAC_ARCH="arm64"
        [ "$(uname -m)" == "x86_64" ] && MAC_ARCH="x64"
        DEST_DIR="$USB_ROOT/bin/mac-$MAC_ARCH"
    fi
    INSTALLED_VARIANT=$(get_installed_backend_variant "$DEST_DIR")
    echo -e "${CYAN}[*] Selected ${WHITE}${BACKEND_VARIANT}${CYAN} backend for detected hardware.${RESET}"

    SERVER_BIN=$(get_engine_binary "$OS_TYPE")
    if [ -z "$SERVER_BIN" ] || [ ! -f "$SERVER_BIN" ] || [ "$INSTALLED_VARIANT" != "$BACKEND_VARIANT" ]; then
        echo -e "${CYAN}[*] Preparing ${BACKEND_VARIANT} llama.cpp backend...${RESET}"
        if [ "$INSTALLED_VARIANT" != "unknown" ] && [ "$INSTALLED_VARIANT" != "$BACKEND_VARIANT" ]; then
            echo -e "${ORANGE}[*] Replacing ${INSTALLED_VARIANT} backend with ${BACKEND_VARIANT}.${RESET}"
        fi

        echo -e "${CYAN}[*] Downloading self-contained Uncensored Studio llama.cpp release...${RESET}"
        local RELEASE="b9668"
        mkdir -p "$DEST_DIR"

        local ASSET_NAME="llama-$RELEASE-bin-ubuntu-x64.tar.gz"
        [ "$BACKEND_VARIANT" == "vulkan" ] && ASSET_NAME="llama-$RELEASE-bin-ubuntu-vulkan-x64.tar.gz"
        if [ "$OS_TYPE" == "mac" ]; then
            ASSET_NAME="llama-$RELEASE-bin-macos-$MAC_ARCH.tar.gz"
        fi

        local ARCHIVE_URL="https://github.com/ggml-org/llama.cpp/releases/download/$RELEASE/$ASSET_NAME"
        local ARCHIVE_PATH="$USB_ROOT/bin/backend.tar.gz"

        echo -e "${CYAN}[>>] Downloading $ASSET_NAME...${RESET}"
        if curl -fSL --progress-bar "$ARCHIVE_URL" -o "$ARCHIVE_PATH"; then
            rm -f "$DEST_DIR"/libggml-vulkan*.so* "$DEST_DIR"/libggml-cuda*.so* "$DEST_DIR"/libggml-hip*.so* 2>/dev/null || true
            tar -xzf "$ARCHIVE_PATH" -C "$DEST_DIR" --strip-components=1 2>/dev/null || tar -xzf "$ARCHIVE_PATH" -C "$DEST_DIR" 2>/dev/null || true
            rm -f "$ARCHIVE_PATH"
            chmod +x "$DEST_DIR"/llama-* 2>/dev/null || true
            if [ -f "$DEST_DIR/llama-server" ]; then
                printf '%s\n' "$BACKEND_VARIANT" > "$DEST_DIR/.backend-variant"
            else
                echo -e "${RED}[!] Backend archive did not contain llama-server.${RESET}"
            fi
        else
            echo -e "${RED}[!] Backend download failed: $ARCHIVE_URL${RESET}"
        fi
        SERVER_BIN=$(get_engine_binary "$OS_TYPE")
    else
        echo -e "${GREEN}[✓] Neural Engine backend binary is verified: $SERVER_BIN${RESET}"
    fi

    local DISCOVERED_MODELS
    DISCOVERED_MODELS=$(get_discovered_models)
    if [ -z "$DISCOVERED_MODELS" ]; then
        echo -e "\n${PINK}[*] No GGUF models discovered.${RESET}"
        echo -e "${CYAN}[>>] Downloading starter Qwen2.5-Coder model (491 MB)...${RESET}"
        mkdir -p "$USB_ROOT/models"
        local MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
        local TARGET_PATH="$USB_ROOT/models/qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
        if curl -fSL --progress-bar "$MODEL_URL" -o "$TARGET_PATH"; then
            echo -e "${GREEN}[✓] Starter model downloaded successfully!${RESET}"
        else
            echo -e "${RED}[!] Model download failed.${RESET}"
        fi
    else
        local MODEL_COUNT
        MODEL_COUNT=$(echo "$DISCOVERED_MODELS" | wc -l)
        echo -e "${GREEN}[✓] Discovered $MODEL_COUNT model(s) in registry.${RESET}"
    fi

    local IMAGE_SETUP_FAILED=0
    if ! install_z_image_turbo "$OS_TYPE" "$BACKEND_VARIANT"; then
        echo -e "${ORANGE}[!] Z-Image Turbo setup did not complete; continuing to other image models.${RESET}"
        IMAGE_SETUP_FAILED=1
    fi
    if [ "$IMAGE_SETUP_FAILED" -eq 0 ]; then
        echo -e "\n${GREEN}[✓] WarStick Neural Setup Complete!${RESET}"
    else
        echo -e "\n${ORANGE}[!] WarStick core setup completed, but one or more selected image components failed.${RESET}"
    fi
    sleep 1.5
}
