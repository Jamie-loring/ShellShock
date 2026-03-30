#!/bin/bash

#############################################
# ShellShock Tool Updater
# Updates GitHub-based tools to latest versions
#############################################

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Tool directories
TOOLS_DIR="$HOME/tools"
GO_TOOLS_DIR="$HOME/go/bin"

# Logging
LOG_FILE="$HOME/shellshock-update-$(date +%Y%m%d-%H%M%S).log"

#############################################
# Helper Functions
#############################################

print_banner() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════╗"
    echo "║     ShellShock Tool Updater v1.0       ║"
    echo "╔════════════════════════════════════════╗"
    echo -e "${NC}"
}

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

print_status() {
    log "${BLUE}[*]${NC} $1"
}

print_success() {
    log "${GREEN}[+]${NC} $1"
}

print_error() {
    log "${RED}[-]${NC} $1"
}

print_warning() {
    log "${YELLOW}[!]${NC} $1"
}

#############################################
# Git Repository Update Functions
#############################################

update_git_repo() {
    local repo_path="$1"
    local repo_name=$(basename "$repo_path")
    
    print_status "Checking $repo_name..."
    
    if [ ! -d "$repo_path/.git" ]; then
        print_warning "$repo_name is not a git repository, skipping"
        return 1
    fi
    
    cd "$repo_path"
    
    # Fetch latest changes
    git fetch origin &>/dev/null || {
        print_error "Failed to fetch updates for $repo_name"
        return 1
    }
    
    # Get current and remote commit hashes
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    
    if [ "$LOCAL" = "$REMOTE" ]; then
        print_success "$repo_name is up to date"
        return 0
    else
        print_warning "$repo_name has updates available"
        echo "  Current: ${LOCAL:0:7}"
        echo "  Remote:  ${REMOTE:0:7}"
        
        if [ "$AUTO_UPDATE" = "true" ]; then
            perform_update "$repo_path" "$repo_name"
        else
            read -p "  Update $repo_name? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                perform_update "$repo_path" "$repo_name"
            fi
        fi
    fi
}

perform_update() {
    local repo_path="$1"
    local repo_name="$2"
    
    cd "$repo_path"
    
    print_status "Updating $repo_name..."
    
    # Stash any local changes
    git stash &>/dev/null
    
    # Pull latest changes
    if git pull origin main 2>/dev/null || git pull origin master 2>/dev/null; then
        print_success "Updated $repo_name successfully"
        
        # Check for requirements.txt or setup.py for Python tools
        if [ -f "requirements.txt" ]; then
            print_status "Installing Python dependencies for $repo_name..."
            pip3 install -r requirements.txt --break-system-packages &>/dev/null || true
        fi
        
        # Check for go.mod for Go tools
        if [ -f "go.mod" ]; then
            print_status "Building Go binary for $repo_name..."
            go build . &>/dev/null || true
            go install . &>/dev/null || true
        fi
        
        # Check for Makefile
        if [ -f "Makefile" ]; then
            print_status "Running make for $repo_name..."
            make &>/dev/null || true
        fi
    else
        print_error "Failed to update $repo_name"
    fi
}

#############################################
# Go Tools Update Functions
#############################################

update_go_tool() {
    local tool_pkg="$1"
    local tool_name=$(basename "$tool_pkg")
    
    print_status "Updating Go tool: $tool_name..."
    
    if go install "$tool_pkg@latest" &>/dev/null; then
        print_success "Updated $tool_name"
    else
        print_error "Failed to update $tool_name"
    fi
}

#############################################
# Main Update Functions
#############################################

update_git_tools() {
    print_banner
    print_status "Scanning for Git repositories in $TOOLS_DIR..."
    
    if [ ! -d "$TOOLS_DIR" ]; then
        print_error "Tools directory not found: $TOOLS_DIR"
        return 1
    fi
    
    local updated=0
    local skipped=0
    
    for repo in "$TOOLS_DIR"/*; do
        if [ -d "$repo/.git" ]; then
            update_git_repo "$repo"
            ((updated++))
        else
            ((skipped++))
        fi
    done
    
    echo
    print_success "Processed $updated repositories ($skipped non-git directories skipped)"
}

update_go_tools() {
    print_status "Updating Go-based tools..."
    
    # Common pentesting Go tools
    GO_TOOLS=(
        "github.com/ffuf/ffuf/v2"
        "github.com/projectdiscovery/nuclei/v3/cmd/nuclei"
        "github.com/projectdiscovery/subfinder/v2/cmd/subfinder"
        "github.com/projectdiscovery/httpx/cmd/httpx"
        "github.com/projectdiscovery/katana/cmd/katana"
        "github.com/projectdiscovery/naabu/v2/cmd/naabu"
        "github.com/projectdiscovery/dnsx/cmd/dnsx"
        "github.com/projectdiscovery/notify/cmd/notify"
        "github.com/tomnomnom/assetfinder"
        "github.com/tomnomnom/waybackurls"
        "github.com/tomnomnom/gf"
        "github.com/tomnomnom/httprobe"
        "github.com/lc/gau/v2/cmd/gau"
        "github.com/hakluke/hakrawler"
        "github.com/glebarez/cero"
    )
    
    for tool in "${GO_TOOLS[@]}"; do
        if [ "$AUTO_UPDATE" = "true" ]; then
            update_go_tool "$tool"
        else
            read -p "Update $(basename $tool)? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                update_go_tool "$tool"
            fi
        fi
    done
}

update_specific_tools() {
    print_status "Updating specific tools with custom update procedures..."
    
    # Update nuclei templates
    if command -v nuclei &>/dev/null; then
        print_status "Updating nuclei templates..."
        nuclei -update-templates &>/dev/null && print_success "Nuclei templates updated" || print_error "Failed to update nuclei templates"
    fi
    
    # Update metasploit
    if command -v msfconsole &>/dev/null; then
        print_status "Updating Metasploit..."
        sudo msfupdate &>/dev/null && print_success "Metasploit updated" || print_error "Failed to update Metasploit"
    fi
    
    # Update searchsploit database
    if command -v searchsploit &>/dev/null; then
        print_status "Updating searchsploit database..."
        sudo searchsploit -u &>/dev/null && print_success "Searchsploit updated" || print_error "Failed to update searchsploit"
    fi
}

#############################################
# Interactive Menu
#############################################

show_menu() {
    echo
    echo "╔════════════════════════════════════════╗"
    echo "║          Update Options                ║"
    echo "╠════════════════════════════════════════╣"
    echo "║  1) Update all Git repositories        ║"
    echo "║  2) Update all Go tools                ║"
    echo "║  3) Update specific tools              ║"
    echo "║  4) Update everything (auto)           ║"
    echo "║  5) Exit                               ║"
    echo "╚════════════════════════════════════════╝"
    echo
}

#############################################
# Main Execution
#############################################

main() {
    AUTO_UPDATE="false"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--auto)
                AUTO_UPDATE="true"
                shift
                ;;
            -g|--git-only)
                update_git_tools
                exit 0
                ;;
            -go|--go-only)
                update_go_tools
                exit 0
                ;;
            -s|--specific)
                update_specific_tools
                exit 0
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo
                echo "Options:"
                echo "  -a, --auto        Auto-update all tools without prompts"
                echo "  -g, --git-only    Update only Git repositories"
                echo "  --go-only         Update only Go tools"
                echo "  -s, --specific    Update specific tools (nuclei, msf, etc.)"
                echo "  -h, --help        Show this help message"
                echo
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Interactive mode
    if [ "$AUTO_UPDATE" = "true" ]; then
        print_banner
        print_status "Running in auto-update mode..."
        update_git_tools
        echo
        update_go_tools
        echo
        update_specific_tools
        echo
        print_success "All updates complete! Log saved to: $LOG_FILE"
    else
        while true; do
            show_menu
            read -p "Select an option [1-5]: " choice
            
            case $choice in
                1)
                    update_git_tools
                    ;;
                2)
                    update_go_tools
                    ;;
                3)
                    update_specific_tools
                    ;;
                4)
                    AUTO_UPDATE="true"
                    update_git_tools
                    echo
                    update_go_tools
                    echo
                    update_specific_tools
                    AUTO_UPDATE="false"
                    ;;
                5)
                    print_success "Exiting. Log saved to: $LOG_FILE"
                    exit 0
                    ;;
                *)
                    print_error "Invalid option"
                    ;;
            esac
        done
    fi
}

# Run main function
main "$@"
