#!/bin/bash
# ============================================
# SHELLSHOCK DARK MODE CONFIGURATOR
# Standalone script to enable dark mode
# Run this after first login to your new account
# ============================================

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << 'EOF'
╔═══════════════════════════════════════════╗
║   ShellShock Dark Mode Configurator       ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

echo -e "${YELLOW}This script will configure:${NC}"
echo "  • MATE Desktop dark theme"
echo "  • GTK 3/4 applications dark mode"
echo "  • Terminal dark theme"
echo "  • Qt applications dark mode"
echo ""
echo -e "${YELLOW}Note: Changes take effect immediately but may require${NC}"
echo -e "${YELLOW}      logging out and back in for full effect.${NC}"
echo ""

read -p "Continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo -e "${CYAN}[*] Configuring dark mode...${NC}"
echo ""

# MATE Desktop (if available)
if command -v gsettings &>/dev/null && gsettings list-schemas | grep -q "org.mate"; then
    echo -e "${GREEN}[+]${NC} Configuring MATE dark theme..."
    
    # Try BlackMATE first, fallback to Adwaita-dark
    if gsettings set org.mate.interface gtk-theme 'BlackMATE' 2>/dev/null; then
        echo -e "${GREEN}[✓]${NC} Set GTK theme to BlackMATE"
    else
        gsettings set org.mate.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
        echo -e "${GREEN}[✓]${NC} Set GTK theme to Adwaita-dark"
    fi
    
    # Icon theme
    gsettings set org.mate.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
    echo -e "${GREEN}[✓]${NC} Set icon theme to Papirus-Dark"
    
    # Window manager theme
    gsettings set org.mate.Marco.general theme 'BlackMATE' 2>/dev/null || \
    gsettings set org.mate.Marco.general theme 'Adwaita-dark' 2>/dev/null || true
    echo -e "${GREEN}[✓]${NC} Set window manager theme"
else
    echo -e "${YELLOW}[!]${NC} MATE Desktop not detected, skipping MATE settings"
fi

# GTK 3 dark mode
echo -e "${GREEN}[+]${NC} Configuring GTK 3 dark mode..."
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Sans 10
EOF
echo -e "${GREEN}[✓]${NC} GTK 3 dark mode enabled"

# GTK 4 dark mode
echo -e "${GREEN}[+]${NC} Configuring GTK 4 dark mode..."
mkdir -p "$HOME/.config/gtk-4.0"
cat > "$HOME/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Sans 10
EOF
echo -e "${GREEN}[✓]${NC} GTK 4 dark mode enabled"

# Terminal dark theme (MATE Terminal)
if command -v mate-terminal &>/dev/null; then
    echo -e "${GREEN}[+]${NC} Configuring MATE Terminal dark theme..."
    mkdir -p "$HOME/.config/mate/terminal"
    cat > "$HOME/.config/mate/terminal/mate-terminal.conf" << 'EOF'
[Default]
background-color='#0C0C0C'
foreground-color='#CCCCCC'
palette='#0C0C0C:#C50F1F:#13A10E:#C19C00:#0037DA:#881798:#3A96DD:#CCCCCC:#767676:#E74856:#16C60C:#F9F1A5:#3B78FF:#B4009E:#61D6D6:#F2F2F2'
use-theme-colors=false
use-system-font=false
font='Monospace 11'
EOF
    echo -e "${GREEN}[✓]${NC} MATE Terminal dark theme configured"
else
    echo -e "${YELLOW}[!]${NC} MATE Terminal not detected, skipping terminal settings"
fi

# Qt dark mode
echo -e "${GREEN}[+]${NC} Configuring Qt dark mode..."
mkdir -p "$HOME/.config/qt5ct"
cat > "$HOME/.config/qt5ct/qt5ct.conf" << 'EOF'
[Appearance]
color_scheme_path=/usr/share/qt5ct/colors/darker.conf
style=Adwaita-Dark
EOF
echo -e "${GREEN}[✓]${NC} Qt dark mode enabled"

# File manager dark mode
if command -v caja &>/dev/null; then
    echo -e "${GREEN}[+]${NC} Configuring Caja (file manager) dark mode..."
    gsettings set org.mate.caja.preferences theme 'dark' 2>/dev/null || true
    echo -e "${GREEN}[✓]${NC} Caja dark mode configured"
fi

echo ""
echo -e "${GREEN}"
cat << 'EOF'
╔═══════════════════════════════════════════╗
║      Dark Mode Configuration Complete     ║
╚═══════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}What to do next:${NC}"
echo "  1. Close all applications"
echo "  2. Log out and log back in"
echo "  3. Enjoy your dark mode setup!"
echo ""
echo -e "${CYAN}Note: Some applications may need to be restarted to apply changes${NC}"
echo ""
