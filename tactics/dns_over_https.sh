#!/bin/bash
# NAME: DNS over HTTPS (DoH) Recon
# DESC: Query Cloudflare DoH API for authoritative A, AAAA, MX, TXT, NS records
# ARGS: true

TARGET="$1"
if [ -z "$TARGET" ]; then
    echo "Error: Target domain required (e.g. example.com)"
    exit 1
fi

DOMAIN=$(echo "$TARGET" | sed -e 's|^https\?://||' -e 's|/.*||' -e 's|:.*||')
echo -e "\033[38;5;51m[*] Querying Cloudflare DoH for: \033[1;37m$DOMAIN\033[0m\n"

for RECORD_TYPE in A AAAA MX TXT NS; do
    echo -e "\033[38;5;214m--- [$RECORD_TYPE RECORDS] ---\033[0m"
    curl -s "https://cloudflare-dns.com/dns-query?name=${DOMAIN}&type=${RECORD_TYPE}" \
         -H "accept: application/dns-json" 2>/dev/null | grep -o '"data":"[^"]*' | sed 's/"data":"/  /' || echo "  (None found)"
done
