#!/bin/bash
# NAME: External IP & Geolocation
# DESC: Fetch public IP, ISP organization, ASN, city, and country details
# ARGS: false

echo -e "\033[38;5;51m[*] Querying ipinfo.io for host public route data...\033[0m"
curl -s -m 8 "https://ipinfo.io/json" 2>/dev/null | grep -E '"(ip|hostname|city|region|country|loc|org|postal|timezone)"' || curl -s "https://ipinfo.io"
