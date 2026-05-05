#!/bin/bash

#############################################
# DHCP Reset Script - enp0s3
# Part of ShellShock Framework
#
# Description: Resets and refreshes the enp0s3
# network interface when dhcpcd becomes flaky.
# Brings the interface down, kills any stale
# dhcpcd state, then brings it back up and
# requests a fresh lease.
#
# Usage:
#   sudo ./fix-dhcp-enp0s3.sh
#############################################

set -euo pipefail

IFACE="enp0s3"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[!] Must be run as root (use sudo)${NC}"
    exit 1
fi

echo -e "${CYAN}[*] Resetting $IFACE...${NC}"

echo -e "${YELLOW}[*] Bringing $IFACE down...${NC}"
ip link set "$IFACE" down

echo -e "${YELLOW}[*] Releasing DHCP lease...${NC}"
dhcpcd --release "$IFACE" 2>/dev/null || true

echo -e "${YELLOW}[*] Killing stale dhcpcd instance for $IFACE...${NC}"
if [[ -f /run/dhcpcd/pid ]]; then
    kill "$(cat /run/dhcpcd/pid)" 2>/dev/null || true
fi
pkill -f "dhcpcd.*$IFACE" 2>/dev/null || true
sleep 1

echo -e "${YELLOW}[*] Flushing interface addresses...${NC}"
ip addr flush dev "$IFACE"

echo -e "${YELLOW}[*] Bringing $IFACE back up...${NC}"
ip link set "$IFACE" up
sleep 1

echo -e "${YELLOW}[*] Requesting fresh DHCP lease...${NC}"
dhcpcd "$IFACE"

echo -e "${GREEN}[+] Done. Current state:${NC}"
ip addr show "$IFACE"
