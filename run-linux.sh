#!/bin/bash
cd "$(dirname "$0")"
USB_ROOT="$(pwd)"

# ─── LOAD CENTRALIZED UI & RUNTIME HELPERS ──────────────────────
source "$USB_ROOT/agent/lib/ui_common.sh"

# ─── BACKGROUND ENGINE INITIALIZATION (LINUX) ───────────────────
start_engine "linux"
trap "stop_engine; exit" SIGINT SIGTERM

# ─── CONSOLE NAVIGATION FRAMEWORK ───────────────────────────────
while true; do
    draw_banner
    ACTIVE_M=$(get_active_model)
    echo -e "${PINK}[WARSTICK COMMAND CONSOLE]${RESET} ${CYAN}// ACTIVE MODEL:${RESET} ${WHITE}${ACTIVE_M}${RESET}"
    echo -e "  [1] Display Prepared Exploit & Recon Prompts"
    echo -e "  [2] Select and Execute Attack Vector (Multi-Step Chaining)"
    echo -e "  [3] Manually Input Custom Offensive Objective"
    echo -e "  [4] Custom Skills & External OSINT Lookups"
    echo -e "  [5] Select / Switch Active LLM Model"
    echo -e "  [6] Open Interactive Web UI Dashboard"
    echo -e "  [7] View Local Red-Team Audit Logs"
    echo -e "  [8] Terminate WarStick Runtime & Purge Memory"
    echo ""
    echo -ne "${PINK}warstick@command-console:~# ${RESET}"
    read CHOICE

    case $CHOICE in
        1)
            draw_banner
            echo -e "${CYAN}─── [EXPLOIT & RECON VECTORS] ──────────────────────────${RESET}\n"
            cat "$USB_ROOT/agent/prompts.txt" 2>/dev/null || echo -e "${ORANGE}[!] Run option 2 first to seed database structure.${RESET}"
            echo -e "\n${PINK}───────────────────────────────────────────────────────${RESET}"
            echo -n "Press [Enter] to cycle back to matrix..."
            read
            ;;
        2)
            draw_banner
            if [ ! -f "$USB_ROOT/agent/prompts.txt" ]; then
                mkdir -p "$USB_ROOT/agent"
                echo " [1] Host Recon: Enumerate network interface adapters, local routing metrics, and scan for active listeners on 22 or 445." > "$USB_ROOT/agent/prompts.txt"
                echo " [2] PrivEsc Audit: Check user assignment privileges, environment fields, and look for misconfigured system binaries." >> "$USB_ROOT/agent/prompts.txt"
                echo " [3] Security Audit: Inspect host native packet firewall status profiles and review security update histories." >> "$USB_ROOT/agent/prompts.txt"
                echo " [4] Persistence Check: Identify cron configurations, background daemons, and tasks loaded at boot initialization." >> "$USB_ROOT/agent/prompts.txt"
            fi

            echo -e "${CYAN}─── [EXPLOIT & RECON VECTORS] ──────────────────────────${RESET}\n"
            cat "$USB_ROOT/agent/prompts.txt"
            echo ""
            echo -ne "${ORANGE}Select target attack vector (1-4): ${RESET}"
            read NUM

            USER_TASK=$(grep "\[$NUM\]" "$USB_ROOT/agent/prompts.txt" | sed "s/\[$NUM\] //")
            if [ -z "$USER_TASK" ]; then
                echo -e "${RED}[!] Error: Invalid matrix vector assignment.${RESET}"
                sleep 1.5
                continue
            fi

            draw_banner
            echo -e "${PINK}[!] VECTOR UNLOCKED ->${RESET} ${WHITE}$USER_TASK${RESET}\n"

            mkdir -p "$USB_ROOT/agent/logs"
            TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
            SESSION_LOG="$USB_ROOT/agent/logs/audit_${TIMESTAMP}.txt"
            MASTER_LOG="$USB_ROOT/agent/agent_log.txt"

            SESSION_HEADER="===============================================================================\n[WARSTICK AUDIT SESSION - ${TIMESTAMP}]\nHost Platform : Linux ($(uname -r))\nTarget Vector : $USER_TASK\n==============================================================================="

            echo -e "$SESSION_HEADER" > "$SESSION_LOG"
            echo -e "\n$SESSION_HEADER" >> "$MASTER_LOG"

            CURRENT_CONTEXT="Host operating system is Linux. The primary objective is: $USER_TASK. Generate valid native Linux terminal utilities only."

            # Arrays to collect summary for the final report
            CYCLE_STEPS=()
            CYCLE_COMMANDS=()
            CYCLE_STATUSES=()

            for STEP in 1 2 3; do
                echo -e "\n${PURPLE}─── OPERATIONAL CYCLE $STEP OF 3 ───────────────────────────${RESET}"

                PAYLOAD=$(cat <<EOF
{"messages": [{"role": "system", "content": "You are an autonomous tactical offensive security engine targeting Linux. Output ONLY the single exact executable Linux terminal command tool (e.g., ip, ss, ps, systemctl, lsblk, ufw, iptables, curl, grep, awk, sed, cut) to advance toward the objective. Do NOT assume Python is installed (do not pipe to python, python3, or python -m json.tool). Use native shell/coreutils tools. Do not think, explain, or discuss. Output ONLY the raw command string."}, {"role": "user", "content": "$CURRENT_CONTEXT"}], "temperature": 0.1, "max_tokens": 512}
EOF
)
                query_llm_with_live_animation "$PAYLOAD"
                RAW_RESPONSE=$(cat "$USB_ROOT/agent/last_response.json" 2>/dev/null)

                EXEC_COMMAND=$(clean_json_command "$RAW_RESPONSE")

                if [ -z "$EXEC_COMMAND" ] || [[ "$EXEC_COMMAND" == *"STOP"* ]]; then
                    echo -e "${CYAN}[*] Vector fully optimized. Closing operational loop.${RESET}"
                    CYCLE_STEPS+=("$STEP")
                    CYCLE_COMMANDS+=("OPTIMIZED / STOPPED")
                    CYCLE_STATUSES+=("COMPLETED")
                    break
                fi

                if [[ "$EXEC_COMMAND" == "REFUSAL:"* ]]; then
                    echo -e "\n${RED}[!] MODEL REFUSAL / SAFETY INTERCEPT:${RESET}"
                    echo -e "${ORANGE}${EXEC_COMMAND#REFUSAL: }${RESET}"
                    CYCLE_STEPS+=("$STEP")
                    CYCLE_COMMANDS+=("REFUSAL: ${EXEC_COMMAND#REFUSAL: }")
                    CYCLE_STATUSES+=("REFUSED")
                    echo -e "\n[REFUSAL] ${EXEC_COMMAND#REFUSAL: }" >> "$SESSION_LOG"
                    echo -e "\n[REFUSAL] ${EXEC_COMMAND#REFUSAL: }" >> "$MASTER_LOG"
                    break
                fi

                if [[ "$EXEC_COMMAND" == "ERROR:"* ]]; then
                    echo -e "\n${RED}[!] INFERENCE ENGINE ERROR:${RESET}"
                    echo -e "${ORANGE}${EXEC_COMMAND#ERROR: }${RESET}"
                    CYCLE_STEPS+=("$STEP")
                    CYCLE_COMMANDS+=("ERROR: ${EXEC_COMMAND#ERROR: }")
                    CYCLE_STATUSES+=("FAILED")
                    echo -e "\n[ERROR] ${EXEC_COMMAND#ERROR: }" >> "$SESSION_LOG"
                    echo -e "\n[ERROR] ${EXEC_COMMAND#ERROR: }" >> "$MASTER_LOG"
                    break
                fi

                if ! validate_shell_command "$EXEC_COMMAND"; then
                    SYNTAX_ERROR="Generated command is syntactically incomplete and was not executed: $EXEC_COMMAND"
                    echo -e "\n${RED}[!] GENERATED COMMAND REJECTED:${RESET}"
                    echo -e "${ORANGE}$SYNTAX_ERROR${RESET}"
                    CYCLE_STEPS+=("$STEP")
                    CYCLE_COMMANDS+=("$EXEC_COMMAND")
                    CYCLE_STATUSES+=("INVALID SYNTAX")
                    echo -e "\n[ERROR] $SYNTAX_ERROR" >> "$SESSION_LOG"
                    echo -e "\n[ERROR] $SYNTAX_ERROR" >> "$MASTER_LOG"
                    break
                fi

                echo -e "${PINK}[>] Executing Shell Payload: ${RESET}${WHITE}$EXEC_COMMAND${RESET}"

                CYCLE_ENTRY="\n-------------------------------------------------------------------------------\n[CYCLE $STEP / 3] $(date +'%H:%M:%S')\nCommand Selected : $EXEC_COMMAND\n-------------------------------------------------------------------------------\n[RAW OUTPUT STREAM]\n"
                echo -e "$CYCLE_ENTRY" >> "$SESSION_LOG"
                echo -e "$CYCLE_ENTRY" >> "$MASTER_LOG"

                echo -e "\n${CYAN}--- SYSTEM DATA INBOUND ---${RESET}"
                CMD_OUTPUT=$(eval "$EXEC_COMMAND" 2>&1)
                echo "$CMD_OUTPUT"
                echo "$CMD_OUTPUT" >> "$SESSION_LOG"
                echo "$CMD_OUTPUT" >> "$MASTER_LOG"

                CYCLE_STEPS+=("$STEP")
                CYCLE_COMMANDS+=("$EXEC_COMMAND")
                CYCLE_STATUSES+=("EXECUTED")

                CLEAN_OUTPUT=$(echo "$CMD_OUTPUT" | tr -d '"' | tr '\n' ' ' | head -c 1000)
                CURRENT_CONTEXT="Host OS is Linux. Objective: $USER_TASK. Previous execution was '$EXEC_COMMAND' which returned: $CLEAN_OUTPUT. Determine the next optimal native Linux CLI step."
            done

            # Write structured Executive Summary at end of log
            SUMMARY_BLOCK="\n===============================================================================\n[EXECUTIVE AUDIT SUMMARY]\nTarget Objective: $USER_TASK\nTotal Cycles Executed: ${#CYCLE_STEPS[@]}\n"
            for i in "${!CYCLE_STEPS[@]}"; do
                SUMMARY_BLOCK+="\n  Cycle ${CYCLE_STEPS[$i]} [${CYCLE_STATUSES[$i]}]: ${CYCLE_COMMANDS[$i]}"
            done
            SUMMARY_BLOCK+="\n===============================================================================\n"

            echo -e "$SUMMARY_BLOCK" >> "$SESSION_LOG"
            echo -e "$SUMMARY_BLOCK" >> "$MASTER_LOG"

            echo -e "\n${GREEN}[✓] Run complete.${RESET}"
            echo -e "${CYAN}[*] Session log saved to: ${WHITE}agent/logs/audit_${TIMESTAMP}.txt${RESET}"
            echo -e "${CYAN}[*] Master log appended: ${WHITE}agent/agent_log.txt${RESET}"
            echo -n "Press [Enter] to refresh terminal environment..."
            read
            ;;
        3)
            draw_banner
            echo -e "${CYAN}Tip: You can call skills directly like: ${WHITE}/geo_ip_lookup 8.8.8.8${CYAN} or ${WHITE}/url_intelligence https://site.com${RESET}"
            echo -ne "${ORANGE}Enter Custom Attack Parameters: ${RESET}"
            read CUSTOM_TASK

            if [ -z "$CUSTOM_TASK" ]; then
                continue
            fi

            draw_banner
            mkdir -p "$USB_ROOT/agent/logs"
            TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
            SESSION_LOG="$USB_ROOT/agent/logs/custom_${TIMESTAMP}.txt"
            MASTER_LOG="$USB_ROOT/agent/agent_log.txt"

            SESSION_HEADER="===============================================================================\n[WARSTICK CUSTOM MISSION - ${TIMESTAMP}]\nHost Platform : Linux ($(uname -r))\nActive Model  : $(get_active_model)\nObjective     : $CUSTOM_TASK\n==============================================================================="

            echo -e "$SESSION_HEADER" > "$SESSION_LOG"
            echo -e "\n$SESSION_HEADER" >> "$MASTER_LOG"

            # Check if user referenced a skill directly (e.g. /geo_ip_lookup 8.8.8.8 or @url_intelligence)
            DIRECT_SKILL_CMD=$(try_direct_skill_execution "$CUSTOM_TASK")

            if [ -n "$DIRECT_SKILL_CMD" ]; then
                EXEC_COMMAND="$DIRECT_SKILL_CMD"
                echo -e "${PINK}[!] Direct Skill Trigger Detected: ${WHITE}$EXEC_COMMAND${RESET}"
            else
                SKILLS_MANIFEST=$(get_skills_manifest)
                PAYLOAD=$(cat <<EOF
{"messages": [{"role": "system", "content": "You are a terminal command utility mapping engine for Linux. Output ONLY the single exact executable Linux terminal command string to resolve the prompt target parameter. Available custom skills: $SKILLS_MANIFEST. You may invoke a custom skill script via \"$USB_ROOT/agent/skills/<script> <arg>\" if matching. Do NOT assume Python is installed (do not use python or pipe to python -m json.tool). Use native CLI utilities like curl, grep, awk, sed, cut, tr, jq. Do not think, explain, or discuss. No markdown, raw command line only."}, {"role": "user", "content": "$CUSTOM_TASK"}], "temperature": 0.1, "max_tokens": 512}
EOF
)
                query_llm_with_live_animation "$PAYLOAD"
                RAW_RESPONSE=$(cat "$USB_ROOT/agent/last_response.json" 2>/dev/null)
                EXEC_COMMAND=$(clean_json_command "$RAW_RESPONSE")
            fi

            if [[ "$EXEC_COMMAND" == "REFUSAL:"* ]]; then
                echo -e "\n${RED}[!] MODEL REFUSAL / SAFETY INTERCEPT:${RESET}"
                echo -e "${ORANGE}${EXEC_COMMAND#REFUSAL: }${RESET}"
                echo -e "\n-------------------------------------------------------------------------------\n[REFUSAL] $(date +'%H:%M:%S')\n${EXEC_COMMAND#REFUSAL: }\n===============================================================================" >> "$SESSION_LOG"
                echo -e "\n-------------------------------------------------------------------------------\n[REFUSAL] $(date +'%H:%M:%S')\n${EXEC_COMMAND#REFUSAL: }\n===============================================================================" >> "$MASTER_LOG"
            elif [[ "$EXEC_COMMAND" == "TEMPLATE:"* ]]; then
                TEMPLATE_PAYLOAD="${EXEC_COMMAND#TEMPLATE: }"
                echo -e "\n${ORANGE}[!] PARAMETER TEMPLATE GENERATED (Requires User Input):${RESET}"
                echo -e "    ${WHITE}${TEMPLATE_PAYLOAD}${RESET}"
                echo -e "\n${CYAN}[*] Replace placeholders (e.g. <target_ip>) with your specific environment target values.${RESET}"
                echo -e "\n-------------------------------------------------------------------------------\n[TEMPLATE] $(date +'%H:%M:%S')\nCommand Template : $TEMPLATE_PAYLOAD\nStatus           : REQUIRES_TARGET_INPUT\n===============================================================================" >> "$SESSION_LOG"
                echo -e "\n-------------------------------------------------------------------------------\n[TEMPLATE] $(date +'%H:%M:%S')\nCommand Template : $TEMPLATE_PAYLOAD\nStatus           : REQUIRES_TARGET_INPUT\n===============================================================================" >> "$MASTER_LOG"
            elif [[ "$EXEC_COMMAND" == "ERROR:"* ]]; then
                echo -e "\n${RED}[!] INFERENCE ENGINE ERROR:${RESET}"
                echo -e "${ORANGE}${EXEC_COMMAND#ERROR: }${RESET}"
                echo -e "\n-------------------------------------------------------------------------------\n[ERROR] $(date +'%H:%M:%S')\n${EXEC_COMMAND#ERROR: }\n===============================================================================" >> "$SESSION_LOG"
                echo -e "\n-------------------------------------------------------------------------------\n[ERROR] $(date +'%H:%M:%S')\n${EXEC_COMMAND#ERROR: }\n===============================================================================" >> "$MASTER_LOG"
            elif ! validate_shell_command "$EXEC_COMMAND"; then
                SYNTAX_ERROR="Generated command is syntactically incomplete and was not executed: $EXEC_COMMAND"
                echo -e "\n${RED}[!] GENERATED COMMAND REJECTED:${RESET}"
                echo -e "${ORANGE}$SYNTAX_ERROR${RESET}"
                echo -e "\n-------------------------------------------------------------------------------\n[ERROR] $(date +'%H:%M:%S')\n$SYNTAX_ERROR\n===============================================================================" >> "$SESSION_LOG"
                echo -e "\n-------------------------------------------------------------------------------\n[ERROR] $(date +'%H:%M:%S')\n$SYNTAX_ERROR\n===============================================================================" >> "$MASTER_LOG"
            else
                echo -e "${PINK}[>] Executing Custom Payload: ${RESET}${WHITE}$EXEC_COMMAND${RESET}"

                CMD_HEADER="\n-------------------------------------------------------------------------------\n[MISSION STEP] $(date +'%H:%M:%S')\nCommand Selected : $EXEC_COMMAND\n-------------------------------------------------------------------------------\n[RAW OUTPUT STREAM]\n"
                echo -e "$CMD_HEADER" >> "$SESSION_LOG"
                echo -e "$CMD_HEADER" >> "$MASTER_LOG"

                echo -e "\n${CYAN}--- RUNTIME OUTPUT STREAM ---${RESET}"
                CMD_OUTPUT=$(eval "$EXEC_COMMAND" 2>&1)
                echo "$CMD_OUTPUT"
                echo "$CMD_OUTPUT" >> "$SESSION_LOG"
                echo "$CMD_OUTPUT" >> "$MASTER_LOG"

                SUMMARY_BLOCK="\n===============================================================================\n[MISSION OUTCOME]\nObjective : $CUSTOM_TASK\nCommand   : $EXEC_COMMAND\nStatus    : EXECUTED\n===============================================================================\n"
                echo -e "$SUMMARY_BLOCK" >> "$SESSION_LOG"
                echo -e "$SUMMARY_BLOCK" >> "$MASTER_LOG"
            fi

            echo -e "\n${GREEN}[✓] Execution complete.${RESET}"
            echo -e "${CYAN}[*] Log saved to: ${WHITE}agent/logs/custom_${TIMESTAMP}.txt${RESET}"
            echo -e "\n${PINK}───────────────────────────────────────────────────────${RESET}"
            echo -n "Press [Enter] to clear viewport matrix..."
            read
            ;;
        4)
            execute_custom_skill_menu
            ;;
        5)
            select_model_menu
            ;;
        6)
            echo -e "${GREEN}[*] Injecting browser GUI pipeline...${RESET}"
            xdg-open "http://127.0.0.1:9931" 2>/dev/null || sensible-browser "http://127.0.0.1:9931" 2>/dev/null
            sleep 1
            ;;
        7)
            draw_banner
            echo -e "${CYAN}─── [HISTORICAL AUDIT STREAM LOGS] ────────────────────${RESET}\n"
            if [ -d "$USB_ROOT/agent/logs" ] && [ "$(ls -A "$USB_ROOT/agent/logs" 2>/dev/null)" ]; then
                echo -e "${WHITE}Available Session Logs:${RESET}"
                ls -1t "$USB_ROOT/agent/logs" | head -n 10
                echo -e "\n${PINK}--- Displaying Latest Audit Stream ---${RESET}\n"
                LATEST_LOG=$(ls -1td "$USB_ROOT/agent/logs"/* 2>/dev/null | head -n 1)
                cat "$LATEST_LOG"
            elif [ -f "$USB_ROOT/agent/agent_log.txt" ]; then
                cat "$USB_ROOT/agent/agent_log.txt"
            else
                echo -e "${ORANGE}[!] Empty buffer. No current transaction loops mapped.${RESET}"
            fi
            echo -e "\n${CYAN}───────────────────────────────────────────────────────${RESET}"
            echo -n "Press [Enter] to slice back to matrix..."
            read
            ;;
        8)
            clear
            echo -e "${PINK}[!] PURGING WARSTICK SYSTEM INFRASTRUCTURE..."
            stop_engine
            echo -e "${CYAN}[✓] Volatile Cache Dropped. Terminal offline.${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}[!] Command entry unrecognized.${RESET}"
            sleep 1
            ;;
    esac
done
