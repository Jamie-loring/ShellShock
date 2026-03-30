#!/bin/bash

#############################################
# VPN Prompt Setup Script
# Part of ShellShock Framework
# Author: Jamie Loring
# Repository: github.com/Jamie-loring/ShellShock
#
# Description: Configures bash prompt to display 
# VPN IP address (tun0) in real-time. Perfect for
# HTB/pentesting environments where you need to 
# track your attack box IP.
#
# Usage: 
#   ./vpn-prompt-setup.sh          - Install VPN prompt
#   ./vpn-prompt-setup.sh remove   - Remove VPN prompt
#############################################

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "═══════════════════════════════════════════════════"
echo "   VPN Prompt Setup - ShellShock Framework"
echo "═══════════════════════════════════════════════════"
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}[!] Do not run this script as root${NC}"
    echo -e "${YELLOW}[*] Run as your normal user to modify their .bashrc${NC}"
    exit 1
fi

BASHRC="$HOME/.bashrc"
BACKUP="$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"

# Function definitions that will be added to .bashrc
VPN_FUNCTION='
# VPN IP Display Function (ShellShock Framework)
get_vpn_ip() {
    local vpn_ip=$(ip -4 addr show tun0 2>/dev/null | grep -oP '"'"'(?<=inet\s)\d+(\.\d+){3}'"'"')
    if [ -n "$vpn_ip" ]; then
        echo "$vpn_ip"
    else
        echo "disconnected"
    fi
}'

# Two-line HTB-style prompt
VPN_PROMPT='export PS1='"'"'┌──(\[\033[01;32m\]\u@\h\[\033[00m\])-[\[\033[01;31m\]$(get_vpn_ip)\[\033[00m\]]\n└─\[\033[01;34m\]\w\[\033[00m\]\$ '"'"''

# Check if VPN prompt is already installed
check_installed() {
    if grep -q "# VPN IP Display Function (ShellShock Framework)" "$BASHRC" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Remove VPN prompt configuration
remove_prompt() {
    echo -e "${YELLOW}[*] Removing VPN prompt configuration...${NC}"
    
    if ! check_installed; then
        echo -e "${RED}[!] VPN prompt not found in .bashrc${NC}"
        exit 1
    fi
    
    # Backup current .bashrc
    cp "$BASHRC" "$BACKUP"
    echo -e "${GREEN}[✓] Backup created: $BACKUP${NC}"
    
    # Remove the VPN function and prompt
    sed -i '/# VPN IP Display Function (ShellShock Framework)/,/^}$/d' "$BASHRC"
    sed -i '/export PS1=.*get_vpn_ip/d' "$BASHRC"
    
    echo -e "${GREEN}[✓] VPN prompt removed successfully${NC}"
    echo -e "${YELLOW}[*] Run 'source ~/.bashrc' or open a new terminal to apply changes${NC}"
    exit 0
}

# Install VPN prompt
install_prompt() {
    # Check if already installed
    if check_installed; then
        echo -e "${YELLOW}[!] VPN prompt already installed${NC}"
        echo -e "${YELLOW}[*] Use './vpn-prompt-setup.sh remove' to uninstall first${NC}"
        exit 1
    fi
    
    # Backup existing .bashrc
    cp "$BASHRC" "$BACKUP"
    echo -e "${GREEN}[✓] Backup created: $BACKUP${NC}"
    
    # Add VPN function and prompt to .bashrc
    echo "$VPN_FUNCTION" >> "$BASHRC"
    echo "$VPN_PROMPT" >> "$BASHRC"
    
    echo -e "${GREEN}[✓] VPN prompt installed successfully${NC}"
    echo ""
    echo -e "${BLUE}Prompt Preview:${NC}"
    echo -e "┌──(user@hostname)-[10.10.16.76]"
    echo -e "└─/current/directory$ "
    echo ""
    echo -e "${YELLOW}[*] Run 'source ~/.bashrc' or open a new terminal to apply changes${NC}"
}

# Main logic
if [ "$1" == "remove" ]; then
    remove_prompt
else
    install_prompt
fi

exit 0
