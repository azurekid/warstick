#!/bin/bash
# NAME: URL Intelligence & Header Parser
# DESC: Parse URL structure, analyze redirect chains, and inspect security headers
# ARGS: true

TARGET="$1"
if [ -z "$TARGET" ]; then
    echo "Error: Target URL required (e.g. https://example.com)"
    exit 1
fi

# Ensure protocol prefix
if [[ ! "$TARGET" =~ ^https?:// ]]; then
    TARGET="https://$TARGET"
fi

echo -e "\033[38;5;51m[*] Analyzing Target URL: \033[1;37m$TARGET\033[0m"

# 1. URL Component Parsing
PROTOCOL=$(echo "$TARGET" | grep -o '^https\?')
HOST_PORT=$(echo "$TARGET" | sed -e 's|^https\?://||' -e 's|/.*||')
HOST=$(echo "$HOST_PORT" | cut -d: -f1)
PORT=$(echo "$HOST_PORT" | grep -o ':[0-9]*$' | tr -d ':')
[ -z "$PORT" ] && [ "$PROTOCOL" == "https" ] && PORT=443
[ -z "$PORT" ] && [ "$PROTOCOL" == "http" ] && PORT=80
PATH_QUERY=$(echo "$TARGET" | sed -e 's|^https\?://[^/]*||')
[ -z "$PATH_QUERY" ] && PATH_QUERY="/"

echo -e "\n\033[38;5;205m--- [URL STRUCTURE] ---\033[0m"
echo "  Scheme   : $PROTOCOL"
echo "  Host     : $HOST"
echo "  Port     : $PORT"
echo "  Path/URI : $PATH_QUERY"

# 2. DNS & IP Resolution
echo -e "\n\033[38;5;205m--- [IP RESOLUTION] ---\033[0m"
host "$HOST" 2>/dev/null | grep "has address" || nslookup "$HOST" 2>/dev/null | grep -A1 "Name:"

# 3. HTTP Response Headers & Security Status
echo -e "\n\033[38;5;205m--- [HTTP HEADERS & SECURITY POLICIES] ---\033[0m"
curl -s -I -L --max-redirs 5 "$TARGET" 2>&1 | grep -iE '^(http/|server:|location:|strict-transport-security:|content-security-policy:|x-frame-options:|x-content-type-options:|set-cookie:|access-control-allow-origin:)'
