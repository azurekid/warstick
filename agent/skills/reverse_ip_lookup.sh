#!/bin/bash
# NAME: Reverse IP & Shared Host Finder
# DESC: Find other domains and virtual hosts co-located on target IP address
# ARGS: true

TARGET="$1"
if [ -z "$TARGET" ]; then
    echo "Error: Target IP or domain required (e.g. 1.1.1.1 or example.com)"
    exit 1
fi

CLEAN_TARGET=$(echo "$TARGET" | sed -e 's|^https\?://||' -e 's|/.*||' -e 's|:.*||')
echo -e "\033[38;5;51m[*] Querying HackerTarget Reverse IP for: \033[1;37m$CLEAN_TARGET\033[0m\n"

curl -s "https://api.hackertarget.com/reverseiplookup/?q=${CLEAN_TARGET}" 2>/dev/null
