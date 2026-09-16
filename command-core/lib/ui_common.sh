#!/bin/bash
#  CENTRALIZED UI & OPERATIONAL LIBRARY (WARSTICK COMMAND CONSOLE)

#  MIAMI VICE / VAPORWAVE ANSI COLOR CODES
export NEON_PINK="\033[38;5;213m"
export PINK="\033[38;5;205m"     # Neon Magenta / Sunset Pink
export ORANGE="\033[38;5;214m"   # Sunset Orange
export SUNSET_ORANGE="\033[38;5;208m"
export VIOLET="\033[38;5;99m"
export AQUA="\033[38;5;45m"
export CYAN="\033[38;5;51m"      # Electric Cyan / Turquoise
export PURPLE="\033[38;5;93m"     # Deep Purple
export WHITE="\033[1;37m"        # High-Vis White
export GREEN="\033[38;5;82m"     # Neon Green
export RED="\033[38;5;196m"      # Bright Red
export BOLD="\033[1m"
export RESET="\033[0m"

#  BANNER RENDERER 
draw_banner() {
    clear
    local BANNER_FILE="$USB_ROOT/command-core/banner.txt"
    if [ -f "$BANNER_FILE" ]; then
        local -a BANNER_PALETTE
        BANNER_PALETTE=("$NEON_PINK" "$PINK" "$VIOLET" "$AQUA" "$CYAN")
        local LINE_NUM=1
        while IFS= read -r line || [ -n "$line" ]; do
            if [[ "$line" == *"COMMAND CONSOLE"* ]]; then
                echo -e "${BOLD}${SUNSET_ORANGE}${line}${RESET}"
                LINE_NUM=$((LINE_NUM + 1))
                continue
            fi
            local COLOR="${BANNER_PALETTE[$(((LINE_NUM - 1) % ${#BANNER_PALETTE[@]}))]}"
            local STYLE=""
            [ "$LINE_NUM" -le 3 ] && STYLE="$BOLD"
            echo -e "${STYLE}${COLOR}${line}${RESET}"
            LINE_NUM=$((LINE_NUM + 1))
        done < "$BANNER_FILE"
    else
        echo -e "${BOLD}${NEON_PINK}__        __          ____  _   _      _${RESET}"
        echo -e "${BOLD}${PINK}\\ \\      / /_ _ _ __/ ___|| |_(_) ___| | __${RESET}"
        echo -e "${BOLD}${VIOLET} \\ \\ /\\ / / _\` | '__\\___ \\| __| |/ __| |/ /${RESET}"
        echo -e "${AQUA}  \\ V  V / (_| | |   ___) | |_| | (__|   <${RESET}"
        echo -e "${CYAN}   \\_/\\_/ \\__,_|_|  |____/ \\__|_|\\___|_|\\_\\${RESET}"
        echo -e "${BOLD}${SUNSET_ORANGE}                 COMMAND CONSOLE${RESET}"
    fi
    echo -e "${RESET}"
}

# LOAD CENTRAL PHRASES
get_phrases() {
    local PHRASES_FILE="$USB_ROOT/command-core/phrases.txt"
    if [ -f "$PHRASES_FILE" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            [ -n "$line" ] && echo "$line"
        done < "$PHRASES_FILE"
    else
        echo "Bypassing the mainframe flux capacitor..."
        echo "Downloading more RAM from the cloud matrix..."
        echo "Consulting the cyber oracle for terminal wisdom..."
        echo "Calibrating optical cyber-lasers..."
        echo "Re-routing the warp drive through port 9931..."
        echo "Synthesizing extra gigawatts of neon energy..."
        echo "Decrypting secret coffee recipes..."
        echo "Overclocking quantum hamsters..."
        echo "Engaging Miami Vice neon turbo-boosters..."
        echo "Compiling discrete custom terminal pipeline..."
    fi
}

# UNCENSORED AI STUDIO INTEGRATION HELPERS
get_uncensored_studio_path() {
    local candidates=(
        "$HOME/GitHub/Uncensored-Local-Studio"
        "/home/cyb3rcat/GitHub/Uncensored-Local-Studio"
        "$(dirname "$USB_ROOT")/Uncensored-Local-Studio"
        "$USB_ROOT/Uncensored-Local-Studio"
    )
    for p in "${candidates[@]}"; do
        if [ -d "$p" ]; then
            echo "$p"
            return 0
        fi
    done
    return 1
}

resolve_model_path() {
    local MODEL_NAME="$1"
    [ -z "$MODEL_NAME" ] && return 1

    if [ -f "$MODEL_NAME" ]; then
        echo "$MODEL_NAME"
        return 0
    fi

    if [ -f "$USB_ROOT/models/$MODEL_NAME" ]; then
        echo "$USB_ROOT/models/$MODEL_NAME"
        return 0
    fi

    local STUDIO_PATH
    STUDIO_PATH=$(get_uncensored_studio_path)
    if [ -n "$STUDIO_PATH" ]; then
        if [ -f "$STUDIO_PATH/app/llm-models/$MODEL_NAME" ]; then
            echo "$STUDIO_PATH/app/llm-models/$MODEL_NAME"
            return 0
        fi
        if [ -f "$STUDIO_PATH/app/models/$MODEL_NAME" ]; then
            echo "$STUDIO_PATH/app/models/$MODEL_NAME"
            return 0
        fi
    fi

    return 1
}

get_discovered_models() {
    local USB_DIR="$USB_ROOT/models"
    local STUDIO_PATH
    STUDIO_PATH=$(get_uncensored_studio_path)

    if [ -d "$USB_DIR" ]; then
        for f in "$USB_DIR"/*.gguf; do
            [ -f "$f" ] && echo "$f"
        done
    fi

    if [ -n "$STUDIO_PATH" ]; then
        if [ -d "$STUDIO_PATH/app/llm-models" ]; then
            for f in "$STUDIO_PATH/app/llm-models"/*.gguf; do
                [ -f "$f" ] && echo "$f"
            done
        fi
        if [ -d "$STUDIO_PATH/app/models" ]; then
            for f in "$STUDIO_PATH/app/models"/*.gguf; do
                [ -f "$f" ] && echo "$f"
            done
        fi
    fi
}

# ACTIVE MODEL MANAGEMENT
get_active_model() {
    local MODEL_CONF="$USB_ROOT/command-core/active_model.txt"
    local SELECTED_MODEL=""
    if [ -f "$MODEL_CONF" ]; then
        SELECTED_MODEL=$(cat "$MODEL_CONF" 2>/dev/null | tr -d '\r\n')
    fi
    local RESOLVED
    RESOLVED=$(resolve_model_path "$SELECTED_MODEL")
    if [ -z "$SELECTED_MODEL" ] || [ -z "$RESOLVED" ]; then
        local FIRST_MODEL
        FIRST_MODEL=$(get_discovered_models | head -n 1)
        if [ -n "$FIRST_MODEL" ]; then
            SELECTED_MODEL=$(basename "$FIRST_MODEL")
            echo "$SELECTED_MODEL" > "$MODEL_CONF"
        fi
    fi
    echo "$SELECTED_MODEL"
}

download_model_menu() {
    draw_banner
    echo -e "${CYAN}─── [MODEL DOWNLOAD CENTER] ────────────────────────────${RESET}\n"
    echo -e "  ${CYAN}[1]${RESET} Qwen2.5 Coder 0.5B Q4_K_M ${PURPLE}[~491 MB]${RESET}"
    echo -e "  ${CYAN}[2]${RESET} Direct HTTPS link to a .gguf file"
    echo -e "  ${ORANGE}[Enter]${RESET} Cancel"
    echo ""
    echo -ne "${ORANGE}Select download source: ${RESET}"
    read DOWNLOAD_CHOICE

    local MODEL_URL=""
    local MODEL_NAME=""
    case "$DOWNLOAD_CHOICE" in
        1)
            MODEL_NAME="qwen2.5-coder-0.5b-instruct-q4_k_m.gguf"
            MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/$MODEL_NAME"
            ;;
        2)
            echo -ne "${ORANGE}Paste direct HTTPS .gguf URL: ${RESET}"
            read MODEL_URL
            local CLEAN_URL="${MODEL_URL%%\?*}"
            MODEL_NAME=$(basename "$CLEAN_URL")
            if [[ "$MODEL_URL" != https://* ]] || [[ ! "$MODEL_NAME" =~ ^[A-Za-z0-9._+-]+\.[Gg][Gg][Uu][Ff]$ ]]; then
                echo -e "${RED}[!] URL must use HTTPS and end with a safe .gguf filename.${RESET}"
                sleep 1.5
                return 1
            fi
            ;;
        *) return 0 ;;
    esac

    local MODELS_DIR="$USB_ROOT/models"
    local TARGET_PATH="$MODELS_DIR/$MODEL_NAME"
    local PART_PATH="$TARGET_PATH.part"
    mkdir -p "$MODELS_DIR"

    if [ -f "$TARGET_PATH" ]; then
        echo -ne "${ORANGE}$MODEL_NAME already exists. Replace it? [y/N]: ${RESET}"
        read REPLACE_MODEL
        [[ "$REPLACE_MODEL" =~ ^[Yy]$ ]] || return 0
    fi

    rm -f "$PART_PATH"
    echo -e "${CYAN}[>>] Downloading ${WHITE}$MODEL_NAME${RESET}"
    if ! curl -fL --progress-bar "$MODEL_URL" -o "$PART_PATH" || [ ! -s "$PART_PATH" ]; then
        rm -f "$PART_PATH"
        echo -e "${RED}[!] Model download failed or produced an empty file.${RESET}"
        return 1
    fi
    mv -f "$PART_PATH" "$TARGET_PATH"
    echo -e "${GREEN}[✓] Model saved to: $TARGET_PATH${RESET}"

    echo -ne "${ORANGE}Activate this model now? [y/N]: ${RESET}"
    read ACTIVATE_MODEL
    if [[ "$ACTIVATE_MODEL" =~ ^[Yy]$ ]]; then
        echo "$MODEL_NAME" > "$USB_ROOT/command-core/active_model.txt"
        echo -e "${PINK}[+] Active model: ${WHITE}$MODEL_NAME${RESET}"
        restart_engine
    fi
}

select_model_menu() {
    draw_banner
    echo -e "${CYAN}─── [NEURAL MODEL REGISTRY] ────────────────────────────${RESET}\n"
    
    local CURRENT_MODEL=$(get_active_model)
    local MODELS=()
    local IDX=1
    
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        local M_NAME=$(basename "$f")
        MODELS+=("$M_NAME")
        local SOURCE_TAG="[USB]"
        if [[ "$f" == *"Uncensored-Local-Studio"* ]]; then
            SOURCE_TAG="[Uncensored-Studio]"
        fi
        if [ "$M_NAME" == "$CURRENT_MODEL" ] || [ "$f" == "$CURRENT_MODEL" ]; then
            echo -e "  ${PINK}[$IDX]${RESET} ${WHITE}$M_NAME${RESET} ${PURPLE}$SOURCE_TAG${RESET} ${GREEN}<<< ACTIVE >>$RESET"
        else
            echo -e "  ${CYAN}[$IDX]${RESET} ${WHITE}$M_NAME${RESET} ${PURPLE}$SOURCE_TAG${RESET}"
        fi
        IDX=$((IDX + 1))
    done < <(get_discovered_models)

    if [ ${#MODELS[@]} -eq 0 ]; then
        echo -e "${RED}[!] No .gguf models discovered inside USB or Uncensored AI Studio directories.${RESET}"
    fi

    echo ""
    echo -e "  ${CYAN}[D]${RESET} Download another GGUF model"
    echo -ne "${ORANGE}Select a model, [D] to download, or press Enter to keep current: ${RESET}"
    read CHOICE

    if [[ "$CHOICE" =~ ^[Dd]$ ]]; then
        download_model_menu
    elif [ -n "$CHOICE" ] && [ "$CHOICE" -ge 1 ] 2>/dev/null && [ "$CHOICE" -le ${#MODELS[@]} ] 2>/dev/null; then
        local NEW_MODEL="${MODELS[$((CHOICE - 1))]}"
        echo "$NEW_MODEL" > "$USB_ROOT/command-core/active_model.txt"
        echo -e "\n${PINK}[+] Switched active model to: ${WHITE}$NEW_MODEL${RESET}"
        restart_engine
    else
        echo -e "\n${CYAN}[*] Active model unchanged: $CURRENT_MODEL${RESET}"
        sleep 1
    fi
}

# CUSTOM SKILL / TOOL REGISTRY MANAGEMENT
get_skills_manifest() {
    local SKILLS_DIR="$USB_ROOT/tactics"
    local MANIFEST=""
    if [ -d "$SKILLS_DIR" ]; then
        for s_file in "$SKILLS_DIR"/*; do
            if [ -f "$s_file" ]; then
                local ext="${s_file##*.}"
                if [[ "$ext" == "sh" || "$ext" == "py" ]]; then
                    local s_name
                    local s_desc
                    s_name=$(grep -m 1 "^# NAME:" "$s_file" | sed 's/^# NAME:[ \t]*//')
                    s_desc=$(grep -m 1 "^# DESC:" "$s_file" | sed 's/^# DESC:[ \t]*//')
                    local b_name
                    b_name=$(basename "$s_file")
                    [ -z "$s_name" ] && s_name="$b_name"
                    MANIFEST+="$b_name: $s_name ($s_desc); "
                fi
            fi
        done
    fi
    echo "$MANIFEST"
}

# Direct skill invocation from prompt (e.g. /geo_ip_lookup 8.8.8.8)
try_direct_skill_execution() {
    local USER_INPUT="$1"
    local SKILLS_DIR="$USB_ROOT/tactics"

    [[ "$USER_INPUT" == /* ]] || return 1

    local CLEAN_INPUT
    CLEAN_INPUT=${USER_INPUT#/}
    
    local FIRST_WORD
    FIRST_WORD=$(echo "$CLEAN_INPUT" | awk '{print $1}')
    local REST_ARGS
    REST_ARGS=$(echo "$CLEAN_INPUT" | cut -d' ' -f2-)
    [ "$REST_ARGS" == "$FIRST_WORD" ] && REST_ARGS=""

    # Check if FIRST_WORD matches any file in skills dir
    local TARGET_SCRIPT=""
    for ext in sh py ""; do
        local CANDIDATE="$SKILLS_DIR/$FIRST_WORD"
        [ -n "$ext" ] && CANDIDATE="$SKILLS_DIR/${FIRST_WORD}.${ext}"
        if [ -f "$CANDIDATE" ]; then
            TARGET_SCRIPT="$CANDIDATE"
            break
        fi
    done

    # Check by skill slug (replacing underscores with dashes or matching without extension)
    if [ -z "$TARGET_SCRIPT" ]; then
        local SLUG_MATCH
        SLUG_MATCH=$(echo "$FIRST_WORD" | tr '-' '_')
        for ext in sh py; do
            if [ -f "$SKILLS_DIR/${SLUG_MATCH}.${ext}" ]; then
                TARGET_SCRIPT="$SKILLS_DIR/${SLUG_MATCH}.${ext}"
                break
            fi
        done
    fi

    if [ -n "$TARGET_SCRIPT" ]; then
        chmod +x "$TARGET_SCRIPT" 2>/dev/null
        if [[ "$TARGET_SCRIPT" == *.py ]]; then
            echo "python3 \"$TARGET_SCRIPT\" $REST_ARGS"
        else
            echo "\"$TARGET_SCRIPT\" $REST_ARGS"
        fi
        return 0
    fi

    return 1
}

execute_custom_skill_menu() {
    local SKILLS_DIR="$USB_ROOT/tactics"
    mkdir -p "$SKILLS_DIR"

    while true; do
        draw_banner
        echo -e "${PINK}[WARSTICK TACTICAL MODULES]${RESET}\n"

        local SKILL_FILES=()
        local SKILL_NAMES=()
        local SKILL_DESCS=()
        local SKILL_NEEDS_ARGS=()
        local IDX=1

        # Scan skills directory for modular scripts (*.sh, *.py)
        for s_file in "$SKILLS_DIR"/*; do
            if [ -f "$s_file" ]; then
                local ext="${s_file##*.}"
                if [[ "$ext" == "sh" || "$ext" == "py" ]]; then
                    local s_name
                    local s_desc
                    local s_args

                    s_name=$(grep -m 1 "^# NAME:" "$s_file" | sed 's/^# NAME:[ \t]*//')
                    s_desc=$(grep -m 1 "^# DESC:" "$s_file" | sed 's/^# DESC:[ \t]*//')
                    s_args=$(grep -m 1 "^# ARGS:" "$s_file" | sed 's/^# ARGS:[ \t]*//')

                    # Fallbacks if headers are missing
                    if [ -z "$s_name" ]; then
                        local base_name
                        base_name=$(basename "$s_file" ".$ext")
                        s_name=$(echo "$base_name" | tr '_' ' ' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
                    fi
                    if [ -z "$s_desc" ]; then
                        s_desc="Execute modular script: $(basename "$s_file")"
                    fi
                    if [ -z "$s_args" ]; then
                        if grep -q '\$1\|sys.argv' "$s_file" 2>/dev/null; then
                            s_args="true"
                        else
                            s_args="false"
                        fi
                    fi

                    SKILL_FILES+=("$s_file")
                    SKILL_NAMES+=("$s_name")
                    SKILL_DESCS+=("$s_desc")
                    SKILL_NEEDS_ARGS+=("$s_args")

                    echo -e "  ${CYAN}[$IDX]${RESET} ${WHITE}$s_name${RESET} ${PURPLE}($(basename "$s_file"))${RESET}"
                    echo -e "      ${PURPLE}↳ $s_desc${RESET}"
                    IDX=$((IDX + 1))
                fi
            fi
        done

        if [ ${#SKILL_FILES[@]} -eq 0 ]; then
            echo -e "  ${ORANGE}[!] No tactical modules discovered inside tactics/${RESET}"
            echo -e "      ${WHITE}Add .sh, .py, or .ps1 modules to tactics/. See tactics/README.md for the format.${RESET}\n"
        fi

        echo -e "\n  ${PINK}[+]${RESET} Create New Tactical Module Template"
        echo -e "  ${ORANGE}[B]${RESET} Back to Main Matrix"
        echo ""
        echo -ne "${ORANGE}Select skill action (1-${#SKILL_FILES[@]}, +, B): ${RESET}"
        read SK_CHOICE

        if [[ "$SK_CHOICE" =~ ^[bB]$ ]]; then
            break
        elif [ "$SK_CHOICE" == "+" ]; then
            draw_banner
            echo -e "${PINK}─── [CREATE MODULAR SKILL TEMPLATE] ────────────────────${RESET}\n"
            echo -ne "${CYAN}Enter File Identifier (e.g. url_scanner or port_probe): ${RESET}"
            read RAW_SLUG
            if [ -z "$RAW_SLUG" ]; then continue; fi
            local SLUG
            SLUG=$(echo "$RAW_SLUG" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-')

            echo -ne "${CYAN}Enter Skill Display Name: ${RESET}"
            read NEW_NAME
            [ -z "$NEW_NAME" ] && NEW_NAME="$SLUG"

            echo -ne "${CYAN}Enter Short Description: ${RESET}"
            read NEW_DESC
            [ -z "$NEW_DESC" ] && NEW_DESC="Custom automated offensive skill"

            echo -ne "${CYAN}Does this skill require a target argument (domain, IP, URL)? (y/n): ${RESET}"
            read HAS_ARG
            local ARGS_VAL="false"
            if [[ "$HAS_ARG" =~ ^[yY]$ ]]; then
                ARGS_VAL="true"
            fi

            local NEW_FILE="$SKILLS_DIR/${SLUG}.sh"
            cat << EOF > "$NEW_FILE"
#!/bin/bash
# NAME: $NEW_NAME
# DESC: $NEW_DESC
# ARGS: $ARGS_VAL

TARGET="\$1"
echo "[*] Executing $NEW_NAME..."
# Add your custom offensive or parsing logic below:
if [ -n "\$TARGET" ]; then
    echo "Processing target: \$TARGET"
fi
EOF
            chmod +x "$NEW_FILE"
            echo -e "\n${GREEN}[✓] Tactical module created at: ${WHITE}tactics/${SLUG}.sh${RESET}"
            echo -e "${CYAN}[*] You can customize its shell/python logic at any time.${RESET}"
            sleep 1.5
            continue
        elif [ -n "$SK_CHOICE" ] && [ "$SK_CHOICE" -ge 1 ] 2>/dev/null && [ "$SK_CHOICE" -le ${#SKILL_FILES[@]} ] 2>/dev/null; then
            local S_INDEX=$((SK_CHOICE - 1))
            local CHOSEN_FILE="${SKILL_FILES[$S_INDEX]}"
            local CHOSEN_NAME="${SKILL_NAMES[$S_INDEX]}"
            local CHOSEN_ARGS="${SKILL_NEEDS_ARGS[$S_INDEX]}"

            draw_banner
            echo -e "${PINK}[!] SKILL ACTIVATED ->${RESET} ${WHITE}$CHOSEN_NAME${RESET}\n"

            local TARGET_ARG=""
            if [ "$CHOSEN_ARGS" == "true" ]; then
                echo -ne "${ORANGE}Enter target parameter (domain, IP, URL, or host): ${RESET}"
                read TARGET_ARG
                if [ -z "$TARGET_ARG" ]; then continue; fi
            fi

            mkdir -p "$USB_ROOT/warstick-logs"
            local TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
            local SESSION_LOG="$USB_ROOT/warstick-logs/skill_${TIMESTAMP}.txt"
            local MASTER_LOG="$USB_ROOT/warstick-logs/warstick.log"

            local SESSION_HEADER="===============================================================================\n[WARSTICK SKILL EXECUTION - ${TIMESTAMP}]\nSkill Name : $CHOSEN_NAME\nScript     : $(basename "$CHOSEN_FILE")\nTarget     : ${TARGET_ARG:-N/A}\n==============================================================================="
            echo -e "$SESSION_HEADER" > "$SESSION_LOG"
            echo -e "\n$SESSION_HEADER" >> "$MASTER_LOG"

            echo -e "${PINK}[>] Invoking Modular Skill: ${RESET}${WHITE}$(basename "$CHOSEN_FILE") ${TARGET_ARG}${RESET}"
            echo -e "\n${CYAN}--- SKILL RUNTIME OUTPUT ---${RESET}"
            
            chmod +x "$CHOSEN_FILE" 2>/dev/null
            local CMD_OUTPUT
            if [[ "$CHOSEN_FILE" == *.py ]]; then
                if command -v python3 >/dev/null 2>&1; then
                    CMD_OUTPUT=$(python3 "$CHOSEN_FILE" "$TARGET_ARG" 2>&1)
                elif command -v python >/dev/null 2>&1; then
                    CMD_OUTPUT=$(python "$CHOSEN_FILE" "$TARGET_ARG" 2>&1)
                else
                    CMD_OUTPUT="Error: Python is not installed on this system. Cannot execute .py skill."
                fi
            else
                CMD_OUTPUT=$("$CHOSEN_FILE" "$TARGET_ARG" 2>&1)
            fi

            echo "$CMD_OUTPUT"
            echo "$CMD_OUTPUT" >> "$SESSION_LOG"
            echo "$CMD_OUTPUT" >> "$MASTER_LOG"

            local SUMMARY_BLOCK="\n===============================================================================\n[SKILL SUMMARY]\nSkill   : $CHOSEN_NAME\nScript  : $(basename "$CHOSEN_FILE")\nStatus  : EXECUTED\n===============================================================================\n"
            echo -e "$SUMMARY_BLOCK" >> "$SESSION_LOG"
            echo -e "$SUMMARY_BLOCK" >> "$MASTER_LOG"

            echo -e "\n${GREEN}[✓] Skill execution completed.${RESET}"
            echo -e "${CYAN}[*] Log saved to: ${WHITE}warstick-logs/skill_${TIMESTAMP}.txt${RESET}"
            echo -n "Press [Enter] to continue..."
            read
        else
            echo -e "${RED}[!] Invalid choice.${RESET}"
            sleep 1
        fi
    done
}

# ─── ENGINE LIFECYCLE CONTROLLERS
get_engine_binary() {
    local OS_TYPE="$1" # mac or linux
    local STUDIO_PATH
    STUDIO_PATH=$(get_uncensored_studio_path)

    if [ "$OS_TYPE" == "mac" ]; then
        local MAC_ARCH="arm64"
        [ "$(uname -m)" == "x86_64" ] && MAC_ARCH="x64"
        if [ -f "$USB_ROOT/bin/mac-$MAC_ARCH/llama-server" ]; then
            echo "$USB_ROOT/bin/mac-$MAC_ARCH/llama-server"
            return 0
        fi
        if [ -n "$STUDIO_PATH" ]; then
            for cand in "$STUDIO_PATH/app/llm-backend/mac/$MAC_ARCH/llama-server"; do
                if [ -f "$cand" ]; then
                    echo "$cand"
                    return 0
                fi
            done
        fi
    else
        if [ -f "$USB_ROOT/bin/linux-x64/llama-server" ]; then
            echo "$USB_ROOT/bin/linux-x64/llama-server"
            return 0
        fi
        if [ -n "$STUDIO_PATH" ]; then
            for cand in "$STUDIO_PATH/app/llm-backend/linux/cuda/llama-server" "$STUDIO_PATH/app/llm-backend/linux/vulkan/llama-server" "$STUDIO_PATH/app/llm-backend/linux/rocm/llama-server" "$STUDIO_PATH/app/llm-backend/linux/cpu/llama-server"; do
                if [ -f "$cand" ]; then
                    echo "$cand"
                    return 0
                fi
            done
        fi
    fi
    return 1
}

get_active_llm_port() {
    if [ -n "$ACTIVE_LLM_PORT" ]; then
        echo "$ACTIVE_LLM_PORT"
        return 0
    fi
    for p in 10086 9931; do
        if curl -s -m 1 "http://127.0.0.1:$p/v1/models" >/dev/null 2>&1 || curl -s -m 1 "http://127.0.0.1:$p/health" >/dev/null 2>&1; then
            ACTIVE_LLM_PORT="$p"
            echo "$p"
            return 0
        fi
    done
    ACTIVE_LLM_PORT=9931
    echo 9931
}

wait_for_server() {
    local PORT=${1:-9931}
    local MAX_WAIT=${2:-30}
    local COUNT=0

    echo -ne "${CYAN}[*] Booting Neural Engine (loading weights into memory)...${RESET}\n"
    while [ $COUNT -lt $MAX_WAIT ]; do
        # Query health or models endpoint
        local STATUS
        STATUS=$(curl -s -m 2 "http://127.0.0.1:${PORT}/health" 2>/dev/null | grep -o '"status":"[^"]*' | sed 's/"status":"//')
        if [ "$STATUS" == "ok" ] || curl -s -m 2 "http://127.0.0.1:${PORT}/v1/models" 2>/dev/null | grep -q '"data"'; then
            echo -e "\r\033[K    ${GREEN}[✓] Engine Ready & Online on Port ${PORT}.${RESET}"
            sleep 0.5
            return 0
        fi
        printf "\r\033[K    ${PINK}[*] Loading Tensor Core... (%ds/%ds)${RESET}" "$COUNT" "$MAX_WAIT"
        sleep 1
        COUNT=$((COUNT + 1))
    done
    echo -e "\r\033[K    ${ORANGE}[!] Engine started in background (taking longer than usual).${RESET}"
    return 1
}

stop_engine() {
    if [ -n "$SERVER_PID" ]; then
        kill "$SERVER_PID" 2>/dev/null
    fi
    pkill -f "llama-server" 2>/dev/null
    sleep 0.5
}

cleanup_runtime_files() {
    rm -f \
        "$USB_ROOT/command-core/last_response.json" \
        "$USB_ROOT/warstick-logs/llama-server.log"
}

start_history_server() {
    if curl -fsS -m 1 "http://127.0.0.1:9932/history" >/dev/null 2>&1; then
        return 0
    fi
    if ! command -v perl >/dev/null 2>&1; then
        echo -e "${ORANGE}[!] Chat history persistence unavailable: Perl is not installed.${RESET}"
        return 1
    fi

    mkdir -p "$USB_ROOT/warstick-logs"
    perl "$USB_ROOT/command-core/lib/history_server.pl" \
        "$USB_ROOT/command-core/chat_history.json" \
        >"$USB_ROOT/warstick-logs/history-server.log" 2>&1 &
    HISTORY_SERVER_PID=$!

    local ATTEMPT
    for ATTEMPT in {1..20}; do
        if curl -fsS -m 1 "http://127.0.0.1:9932/history" >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
    done

    echo -e "${ORANGE}[!] Chat history service failed to start.${RESET}"
    stop_history_server
    return 1
}

stop_history_server() {
    if [ -n "$HISTORY_SERVER_PID" ]; then
        kill "$HISTORY_SERVER_PID" 2>/dev/null || true
        wait "$HISTORY_SERVER_PID" 2>/dev/null || true
        HISTORY_SERVER_PID=""
    fi
}

start_image_server() {
    if curl -fsS -m 1 "http://127.0.0.1:9933/models" 2>/dev/null | grep -q '"models"'; then
        echo -e "${GREEN}[✓] Image generation service is online on Port 9933.${RESET}"
        return 0
    fi

    if curl -fsS -m 1 "http://127.0.0.1:9933/health" >/dev/null 2>&1; then
        local IMAGE_SCRIPT="$USB_ROOT/command-core/lib/image_server.pl"
        local LISTENER_PID=""
        command -v lsof >/dev/null 2>&1 && LISTENER_PID=$(lsof -tiTCP:9933 -sTCP:LISTEN 2>/dev/null | head -n 1)
        if [ -n "$LISTENER_PID" ] && [[ "$(ps -p "$LISTENER_PID" -o command= 2>/dev/null)" == *"$IMAGE_SCRIPT"* ]]; then
            echo -e "${ORANGE}[*] Replacing an outdated WarStick image service on Port 9933.${RESET}"
            kill "$LISTENER_PID" 2>/dev/null || true
            wait "$LISTENER_PID" 2>/dev/null || true
        else
            echo -e "${RED}[!] Port 9933 is occupied by an incompatible image service.${RESET}"
            echo -e "${ORANGE}    Stop the other service, then restart WarStick.${RESET}"
            return 1
        fi
    fi
    if ! command -v perl >/dev/null 2>&1; then
        return 1
    fi

    local OS_TYPE="$1"
    local BIN_ROOT="$USB_ROOT/bin/linux-x64/image"
    [ "$OS_TYPE" == "mac" ] && BIN_ROOT="$USB_ROOT/bin/mac-arm64/image"
    local SD_BINARY
    SD_BINARY=$(find "$BIN_ROOT" -type f -name 'sd-cli' -print -quit 2>/dev/null)
    local MODELS_DIR="$USB_ROOT/models/image"
    if [ -z "$SD_BINARY" ] || [ ! -d "$MODELS_DIR" ]; then
        echo -e "${ORANGE}[*] No image model bundle is installed. Run setup to enable image generation.${RESET}"
        return 1
    fi

    mkdir -p "$USB_ROOT/warstick-logs" "$USB_ROOT/generated-images"
    chmod +x "$SD_BINARY" 2>/dev/null || true
    perl "$USB_ROOT/command-core/lib/image_server.pl" \
        "$SD_BINARY" "$MODELS_DIR" "$USB_ROOT/generated-images" \
        >"$USB_ROOT/warstick-logs/image-server.log" 2>&1 &
    IMAGE_SERVER_PID=$!

    local ATTEMPT
    for ATTEMPT in {1..20}; do
        if curl -fsS -m 1 "http://127.0.0.1:9933/models" 2>/dev/null | grep -q '"models"'; then
            echo -e "${GREEN}[✓] Image generation service is online on Port 9933.${RESET}"
            return 0
        fi
        sleep 0.1
    done
    echo -e "${ORANGE}[!] Image generation service failed to start. See warstick-logs/image-server.log.${RESET}"
    stop_image_server
    return 1
}

stop_image_server() {
    if [ -n "$IMAGE_SERVER_PID" ]; then
        kill "$IMAGE_SERVER_PID" 2>/dev/null || true
        wait "$IMAGE_SERVER_PID" 2>/dev/null || true
        IMAGE_SERVER_PID=""
    fi
}

# Ensure Linux shared objects are real files (FAT/exFAT USB copies drop symlinks).
ensure_linux_runtime_libs() {
    local BIN_DIR="$1"

    [ -d "$BIN_DIR" ] || return 1

    if [ ! -f "$BIN_DIR/libggml-cpu-x64.so" ]; then
        echo -e "${RED}[!] Missing Linux x64 CPU backend plugin in $BIN_DIR${RESET}"
        echo -e "${ORANGE}    Expected: libggml-cpu-x64.so${RESET}"
        return 1
    fi

    # Materialize SONAME aliases as hard copies so noexec/FAT USB media still works.
    # The exact patch version (e.g. libllama.so.0.0.9668) varies between llama.cpp
    # releases, so discover the shipped versioned file instead of hardcoding it.
    local soname_base
    local versioned_file
    local soname_bases=(
        "libggml-base.so.0"
        "libggml.so.0"
        "libllama-common.so.0"
        "libllama.so.0"
        "libmtmd.so.0"
    )

    for soname_base in "${soname_bases[@]}"; do
        if [ -f "$BIN_DIR/$soname_base" ] && [ ! -L "$BIN_DIR/$soname_base" ]; then
            continue
        fi
        versioned_file=$(find "$BIN_DIR" -maxdepth 1 -type f -name "${soname_base}.*" -print -quit 2>/dev/null)
        if [ -n "$versioned_file" ]; then
            cp -f "$versioned_file" "$BIN_DIR/$soname_base" 2>/dev/null || true
        fi
    done

    if [ -f "$BIN_DIR/libllama-server-impl.so.0" ] && { [ ! -f "$BIN_DIR/libllama-server-impl.so" ] || [ -L "$BIN_DIR/libllama-server-impl.so" ]; }; then
        cp -f "$BIN_DIR/libllama-server-impl.so.0" "$BIN_DIR/libllama-server-impl.so" 2>/dev/null || true
    fi

    # Best-effort execute bits (ignored on some FAT mounts).
    chmod +x "$BIN_DIR/llama-server" "$BIN_DIR"/*.so* 2>/dev/null || true
    return 0
}

start_engine() {
    local OS_TYPE="$1" # mac or linux
    local ACTIVE_MODEL
    local MODEL_PATH
    local SERVER_BIN
    local SERVER_LOG
    local LAUNCH_ENV=()
    local TARGET_PORT=9931

    # Check if LLM server is already online on port 10086 (Uncensored Studio) or 9931
    for p in 10086 9931; do
        if curl -s -m 1 "http://127.0.0.1:$p/v1/models" >/dev/null 2>&1 || curl -s -m 1 "http://127.0.0.1:$p/health" >/dev/null 2>&1; then
            echo -e "${GREEN}[✓] Reusing active LLM Engine server on Port $p.${RESET}"
            ACTIVE_LLM_PORT="$p"
            return 0
        fi
    done

    ACTIVE_MODEL=$(get_active_model)
    MODEL_PATH=$(resolve_model_path "$ACTIVE_MODEL")
    SERVER_LOG="$USB_ROOT/warstick-logs/llama-server.log"
    mkdir -p "$USB_ROOT/warstick-logs"

    if [ -z "$MODEL_PATH" ] || [ ! -f "$MODEL_PATH" ]; then
        echo -e "${RED}[!] Error: Model not found for: $ACTIVE_MODEL${RESET}"
        return 1
    fi

    stop_engine
    : > "$SERVER_LOG"

    SERVER_BIN=$(get_engine_binary "$OS_TYPE")
    if [ -z "$SERVER_BIN" ] || [ ! -f "$SERVER_BIN" ]; then
        echo -e "${RED}[!] Engine binary not found for $OS_TYPE. Run the WarStick setup script first.${RESET}"
        return 1
    fi

    local BIN_DIR
    BIN_DIR=$(dirname "$SERVER_BIN")
    if [ "$OS_TYPE" == "mac" ]; then
        xattr -cr "$BIN_DIR" 2>/dev/null
        chmod +x "$SERVER_BIN" 2>/dev/null
    else
        ensure_linux_runtime_libs "$BIN_DIR" 2>/dev/null || true
        chmod +x "$SERVER_BIN" 2>/dev/null || true
        export LD_LIBRARY_PATH="$BIN_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        LAUNCH_ENV=(env "LD_LIBRARY_PATH=$LD_LIBRARY_PATH")
    fi

    ACTIVE_LLM_PORT="$TARGET_PORT"

    "${LAUNCH_ENV[@]}" "$SERVER_BIN" \
        --models-dir "$USB_ROOT/models" \
        --models-max 1 \
        --models-autoload \
        -c 4096 \
        --host 0.0.0.0 \
        --port "$TARGET_PORT" \
        --path "$USB_ROOT/command-core/webui" \
        >"$SERVER_LOG" 2>&1 &
    SERVER_PID=$!

    if ! wait_for_server "$TARGET_PORT" 35; then
        echo -e "${RED}[!] Neural engine failed to become ready on port $TARGET_PORT.${RESET}"
        if [ -s "$SERVER_LOG" ]; then
            echo -e "${ORANGE}─── last engine log lines ─────────────────────────────${RESET}"
            tail -n 20 "$SERVER_LOG" 2>/dev/null
            echo -e "${ORANGE}───────────────────────────────────────────────────────${RESET}"
            echo -e "${CYAN}Full log: $SERVER_LOG${RESET}"
        fi
        return 1
    fi
}

restart_engine() {
    local OS_NAME="mac"
    if [[ "$(uname -s)" == "Linux" ]]; then
        OS_NAME="linux"
    fi
    start_engine "$OS_NAME"
}

# REAL-TIME ASYNC SPINNER & REQUEST RUNNER
query_llm_with_live_animation() {
    local PAYLOAD="$1"
    local ACTIVE_MODEL
    local MODEL_ID

    if ! printf '%s' "$PAYLOAD" | grep -qE '"model"[[:space:]]*:'; then
        ACTIVE_MODEL=$(get_active_model)
        MODEL_ID=$(basename "$ACTIVE_MODEL")
        MODEL_ID=${MODEL_ID%.[gG][gG][uU][fF]}
        if [ -n "$MODEL_ID" ]; then
            PAYLOAD="${PAYLOAD%\}},\"model\":\"$(json_escape "$MODEL_ID")\"}"
        fi
    fi

    mkdir -p "$USB_ROOT/warstick-logs"
    local RESP_FILE="$USB_ROOT/command-core/last_response.json"
    rm -f "$RESP_FILE"

    local LLM_PORT
    LLM_PORT=$(get_active_llm_port)

    # Check if server is running before attempting query
    if ! curl -s -m 1 "http://127.0.0.1:$LLM_PORT/health" >/dev/null 2>&1 && ! curl -s -m 1 "http://127.0.0.1:$LLM_PORT/v1/models" >/dev/null 2>&1; then
        echo -e "${ORANGE}[!] Neural Engine not responding on Port $LLM_PORT. Re-launching...${RESET}"
        restart_engine
        LLM_PORT=$(get_active_llm_port)
    fi

    # Trigger curl in the background so animation runs simultaneously
    curl -s -X POST "http://127.0.0.1:$LLM_PORT/v1/chat/completions" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD" > "$RESP_FILE" 2>/dev/null &
    local CURL_PID=$!

    local FUNNY_PHRASES=()
    while IFS= read -r phrase || [ -n "$phrase" ]; do
        [ -n "$phrase" ] && FUNNY_PHRASES+=("$phrase")
    done < <(get_phrases)

    if [ ${#FUNNY_PHRASES[@]} -eq 0 ]; then
        FUNNY_PHRASES=("Engaging Miami Vice neon turbo-boosters..." "Compiling discrete custom terminal pipeline..." "Synthesizing tensor maps...")
    fi

    local GLYPHS=("◢" "◣" "◤" "◥" "█" "▓" "▒" "░" "◆" "◇" "◈" "▲" "▼")
    local COLORS=("$PINK" "$ORANGE" "$CYAN" "$PURPLE")

    local TICK=0
    local PHRASE_INDEX=$((RANDOM % ${#FUNNY_PHRASES[@]}))
    local CURRENT_PHRASE="${FUNNY_PHRASES[$PHRASE_INDEX]}"

    echo -ne "${CYAN}[*] Initializing Neural Bus...${RESET}\n"

    # Spin actively while curl is processing in background
    while kill -0 $CURL_PID 2>/dev/null; do
        TICK=$((TICK + 1))

        # Rotate phrase dynamically every ~4.5 seconds (38 ticks at 120ms)
        if [ $((TICK % 38)) -eq 0 ]; then
            PHRASE_INDEX=$(((PHRASE_INDEX + 1 + (RANDOM % (${#FUNNY_PHRASES[@]} - 1))) % ${#FUNNY_PHRASES[@]}))
            CURRENT_PHRASE="${FUNNY_PHRASES[$PHRASE_INDEX]}"
        fi

        local G1=${GLYPHS[$((RANDOM % ${#GLYPHS[@]}))]}
        local G2=${GLYPHS[$((RANDOM % ${#GLYPHS[@]}))]}
        local C1=${COLORS[$((RANDOM % ${#COLORS[@]}))]}
        local C2=${COLORS[$((RANDOM % ${#COLORS[@]}))]}
        local HZ=$(( 120 + (RANDOM % 840) ))

        printf "\r\033[K    %b[%b%b%b%b]%b %s %b%dHz%b " "$C1" "$G1" "$C2" "$G2" "$C1" "$RESET" "$CURRENT_PHRASE" "$WHITE" "$HZ" "$RESET"
        sleep 0.12
    done

    wait $CURL_PID 2>/dev/null

    if [ ! -s "$RESP_FILE" ]; then
        printf "\r\033[K    %b[!] Engine returned empty response.%b\n" "$RED" "$RESET"
    else
        printf "\r\033[K    %b[✓] Neural Synthesis Complete.%b\n" "$CYAN" "$RESET"
    fi
}

json_escape() {
    local value="$1"

    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

extract_chat_response() {
    local raw_response="$1"
    local content=""

    if command -v jq >/dev/null 2>&1; then
        content=$(printf '%s' "$raw_response" | jq -r '.choices[0].message.content // .choices[0].message.reasoning_content // empty' 2>/dev/null)
    elif command -v perl >/dev/null 2>&1; then
        content=$(printf '%s' "$raw_response" | perl -MJSON::PP -0777 -e '
            my $data = eval { decode_json(<STDIN>) } or exit;
            my $message = $data->{choices}[0]{message} || {};
            print $message->{content} // $message->{reasoning_content} // "";
        ' 2>/dev/null)
    fi

    if [ -z "$content" ]; then
        content=$(printf '%s' "$raw_response" | sed -n 's/.*"content":"//;s/"}.*//p' | head -n 1)
        content=${content//\\n/$'\n'}
        content=${content//\\r/$'\r'}
        content=${content//\\t/$'\t'}
        content=${content//\\\"/\"}
        content=${content//\\\\/\\}
    fi

    printf '%s' "$content"
}

#  GENERATED COMMAND VALIDATION
validate_shell_command() {
    local command_text="$1"

    [ -n "$command_text" ] || return 1
    if printf '%s\n' "$command_text" | grep -qE '<<([^<]|$)'; then
        return 1
    fi

    bash -n -c "$command_text" >/dev/null 2>&1
}

#  RESPONSE JSON PARSER & REFUSAL DETECTOR
clean_json_command() {
    local raw_input="$1"
    local content=""
    local final_cmd=""

    # 1. Decode the response before inspecting command text so escaped quotes
    # inside shell arguments cannot be mistaken for JSON delimiters.
    content=$(extract_chat_response "$raw_input")

    if [ -z "$content" ]; then
        content="$raw_input"
    fi

    # Convert escaped newlines to actual newlines for processing
    content=$(echo -e "$content")

    # 2. Remove XML/think tags using sed
    content=$(echo "$content" | sed -e 's/<think>.*<\/think>//g' -e 's/<thought>.*<\/thought>//g' -e 's/\[INST\]//g' -e 's/\[\/INST\]//g')

    # 3. Extract markdown code blocks if present (prefer last block)
    local code_block=$(echo "$content" | sed -n '/```/,/```/p' | grep -v '```' | tail -20)
    if [ -n "$code_block" ]; then
        content="$code_block"
    fi

    # 4. Clean and filter lines - remove prose
    # Loop through lines and find the best command candidate
    local line
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        # Skip empty lines
        [ -z "$line" ] && continue
        
        # Skip JSON structural artifacts
        if echo "$line" | grep -qE '^\{|\}|^\[|\]|^"|^choices:|^data:'; then
            continue
        fi
        
        # Skip comments and markdown markers
        if echo "$line" | grep -qE '^#|^```|^---|^==='; then
            continue
        fi
        
        # Skip very short lines (< 4 chars)
        [ ${#line} -lt 4 ] && continue
        
        # Skip pure prose lines starting with common prose patterns
        if echo "$line" | grep -iqE '^(We need|Lets|I will|The user|The |Firsts|Note:|Option|Step [0-9]|Here is|To accomplish|This command|According to|In order to|So |This |That |Now |Just |And |But |Or |Im|You can|More info|Output|Result|Results|It |He |She |They |What |When |Where |Why |How |The best|The most|The only|Heres|Thats)'; then
            continue
        fi
        
        # Skip lines that end with sentence-ending punctuation (likely prose)
        if echo "$line" | grep -qE '\.$|^[A-Z][a-z]+(\s+[a-z]+)*\.$'; then
            continue
        fi
        
        # Skip if it looks like starting a number or is just capitalized prose
        if echo "$line" | grep -qE '^[0-9]+\.|^[A-Z][a-z]+(\s+[a-z]+)*$'; then
            continue
        fi
        
        # If line has shell operators or looks like a command, accept it
        if echo "$line" | grep -qE '[/\-|><&$*\(\)\[\]`"\047]'; then
            # Reject if it ends with punctuation
            if ! echo "$line" | grep -qE '\.|!|\?$'; then
                final_cmd="$line"
                break
            fi
        fi
    done <<< "$content"

    # 5. Fallback: if no good command found, try to extract from any remaining content
    if [ -z "$final_cmd" ]; then
        final_cmd=$(echo "$content" | tail -5 | grep -v '^[A-Z][a-z]*' | tail -1)
    fi

    # 6. Clean up markdown wrappers, escaped newlines, and leading shell prompt symbols like $, #, >, %
    final_cmd=$(echo "$final_cmd" | sed -e "s/^\`\`\`//g" -e "s/\`\`\`$//g" -e 's/\\n/ /g' -e 's/\\t/ /g' -e "s/\\\\//g" -e "s/^\`//g" -e "s/\`$//g" | sed -E 's/^[[:space:]]*[\$#>%][[:space:]]+//')
    final_cmd=$(printf '%s' "$final_cmd" | sed -E 's/^\*\*(.*)\*\*$/\1/;s/^__(.*)__$/\1/')

    # 7. Guard: never return raw JSON payload
    if echo "$final_cmd" | grep -qE '^\{|^choices:|^\[\{'; then
        final_cmd=""
    fi

    # 8. Detect unpopulated placeholder templates
    if echo "$final_cmd" | grep -iqE '<[a-zA-Z0-9_\-]+>|\[(target|ip|port|host|username|password|path|file)'; then
        echo "TEMPLATE: $final_cmd"
    elif echo "$final_cmd" | grep -iqE 'cannot assist|sorry|illegal|unethical|certified security|as an ai|i am unable|as a language model|policy|disclaimer'; then
        echo "REFUSAL: $final_cmd"
    elif [ -z "$final_cmd" ]; then
        echo "ERROR: Model did not produce a clean executable command."
    else
        echo "$final_cmd"
    fi
}
