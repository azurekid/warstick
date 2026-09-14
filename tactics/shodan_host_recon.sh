#!/bin/bash
# NAME: Shodan InternetDB Host Recon
# DESC: Query open ports, vulnerabilities (CVEs), and tags for target IP
# ARGS: true

TARGET="$1"
if [ -z "$TARGET" ]; then
    echo "Error: Target IP required (e.g. 1.1.1.1)"
    exit 1
fi

CLEAN_IP=$(echo "$TARGET" | sed -e 's|^https\?://||' -e 's|/.*||' -e 's|:.*||')
echo -e "\033[38;5;51m[*] Querying Shodan InternetDB for: \033[1;37m$CLEAN_IP\033[0m\n"

curl -s "https://internetdb.shodan.io/${CLEAN_IP}" 2>/dev/null | grep -E '"(ip|ports|cpes|hostnames|vulns|tags)"' || curl -s "https://internetdb.shodan.io/${CLEAN_IP}"
