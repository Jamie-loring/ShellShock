#!/bin/bash
# ShellShock Bootstrap Audit
# Mirrors install.sh phases — validates the install is intact.
# Read-only. Does not modify anything.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS=0; FAIL=0; WARN=0

pass() { echo -e "  ${GREEN}[PASS]${NC} $1"; PASS=$((PASS+1)); }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; FAIL=$((FAIL+1)); }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; WARN=$((WARN+1)); }
section() { echo -e "\n${CYAN}${BOLD}── $1 ──${NC}"; }

cmd() {
    if command -v "$1" &>/dev/null; then pass "$1"
    else fail "$1 not in PATH"; fi
}
file() {
    local path="$1" label="${2:-$1}"
    if [[ -f "$path" && -s "$path" ]]; then pass "$label"
    elif [[ -f "$path" ]]; then fail "$label (empty — download failed)"
    else fail "$label missing"; fi
}
dir() {
    if [[ -d "$1" ]]; then pass "${2:-$1}"
    else fail "${2:-$1} missing"; fi
}
pkg() {
    if dpkg -l "$1" 2>/dev/null | grep -q "^ii"; then pass "$1"
    else fail "$1 not installed"; fi
}
pymod() {
    if python3 -c "import $1" 2>/dev/null; then pass "$1 (python)"
    else fail "$1 (python) not importable"; fi
}
pipx_pkg() {
    if pipx list 2>/dev/null | grep -q "$1"; then pass "$1 (pipx)"
    else fail "$1 (pipx) not installed"; fi
}
gem_pkg() {
    if gem list -i "$1" &>/dev/null; then pass "$1 (gem)"
    else fail "$1 (gem) not installed"; fi
}
gobin() {
    if [[ -f "$HOME/go/bin/$1" ]] || command -v "$1" &>/dev/null; then pass "$1 (go)"
    else fail "$1 (go) missing — reinstall: go install"; fi
}

echo -e "${BOLD}ShellShock Bootstrap Audit${NC}  —  $(date)"
echo -e "Home: $HOME"

# ── PHASE 3: CORE PACKAGES ────────────────────────────────────────────────────
section "Phase 3 — Core Packages"
for p in curl wget git vim tmux unzip p7zip-full build-essential gcc make cmake \
          python3 python3-pip pipx ruby ruby-dev \
          nmap masscan socat tcpdump wireshark tshark dnsutils ldap-utils openvpn \
          nikto wfuzz sqlmap whatweb \
          gdb patchelf nasm mingw-w64 osslsigncode \
          binwalk steghide exiftool foremost \
          john hashcat hydra \
          enum4linux smbmap nbtscan \
          metasploit-framework exploitdb \
          proxychains4 sshpass rlwrap \
          docker.io nodejs npm; do
    pkg "$p"
done

# ── PHASE 5: GO ───────────────────────────────────────────────────────────────
section "Phase 5 — Go"
if [[ -f /usr/local/go/bin/go ]]; then
    pass "Go installed: $(/usr/local/go/bin/go version 2>/dev/null)"
else
    fail "Go not found at /usr/local/go/bin/go"
fi

# ── PHASE 6: SHELL ENVIRONMENT ────────────────────────────────────────────────
section "Phase 6 — Shell Environment"
file "$HOME/.shellshock_env" "~/.shellshock_env"
if grep -q "shellshock_env" "$HOME/.bashrc" 2>/dev/null \
   || grep -q "shellshock_env" "$HOME/.zshrc" 2>/dev/null \
   || grep -q "shellshock_env" "$HOME/.profile" 2>/dev/null; then
    pass "~/.shellshock_env sourced by shell config"
else
    warn "~/.shellshock_env not referenced in .bashrc / .zshrc / .profile"
fi

# ── PHASE 7: PYTHON TOOLS ─────────────────────────────────────────────────────
section "Phase 7 — Python Tools"
for m in impacket bloodhound bloodyAD mitm6 pwntools pycryptodome scapy \
          flask paramiko PyJWT requests beautifulsoup4 lxml pyOpenSSL \
          python_dotenv mcp interpreter playwright; do
    pymod "$m"
done
cmd nxc; cmd netexec
pipx_pkg certipy-ad
pipx_pkg ldapdomaindump
pipx_pkg sprayhound
pipx_pkg ROPgadget
pipx_pkg ropper
pipx_pkg crackmapexec

# gMSADumper (cloned, not pip)
dir "$HOME/tools/repos/gMSADumper" "gMSADumper repo"
cmd gMSADumper

# ── PHASE 8: RUBY TOOLS ───────────────────────────────────────────────────────
section "Phase 8 — Ruby Tools"
gem_pkg evil-winrm
gem_pkg one_gadget
gem_pkg haiti-hash

# ── PHASE 9: GO SECURITY TOOLS ───────────────────────────────────────────────
section "Phase 9 — Go Security Tools"
for t in httpx subfinder dnsx nuclei ffuf gobuster kerbrute chisel ligolo-ng \
          interactsh-client katana naabu gf anew; do
    gobin "$t"
done

# ── PHASE 10: REPOS, WORDLISTS & SCRIPTS ─────────────────────────────────────
section "Phase 10 — Repos"
for r in SecLists penelope PayloadsAllTheThings Responder enum4linux-ng pwndbg; do
    dir "$HOME/tools/repos/$r" "$r"
done

section "Phase 10 — Wordlists"
dir  "$HOME/wordlists/SecLists"          "~/wordlists/SecLists"
file "$HOME/wordlists/rockyou.txt"       "rockyou.txt"
for l in common-dirs big-dirs medium-dirs dirbuster-medium dirbuster-small \
          params subdomains-5k subdomains-20k vhosts; do
    [[ -e "$HOME/wordlists/${l}.txt" ]] && pass "wordlist symlink: ${l}.txt" \
        || warn "wordlist symlink missing: ${l}.txt (non-critical)"
done

section "Phase 10 — Quick-Access Scripts"
file "$HOME/tools/scripts/linpeas.sh"   "linpeas.sh"
file "$HOME/tools/scripts/winpeas.exe"  "winpeas.exe"
file "$HOME/tools/scripts/penelope.py"  "penelope.py"
file "$HOME/tools/scripts/pspy64"       "pspy64"
cmd  stegseek
cmd  rustscan
cmd  feroxbuster

# ── PHASE 10.5: BINARY EXPLOITATION ──────────────────────────────────────────
section "Phase 10.5 — Binary Exploitation"
dir "$HOME/tools/repos/pwndbg" "pwndbg repo"
if [[ -f "$HOME/.gdbinit" ]] && grep -q "pwndbg\|gef" "$HOME/.gdbinit" 2>/dev/null; then
    pass ".gdbinit configured (pwndbg or gef)"
else
    warn ".gdbinit not configured — pwndbg/gef may not auto-load"
fi
[[ -f "$HOME/.gdbinit-gef.py" ]] && pass "gef downloaded" || warn "gef not downloaded (~/.gdbinit-gef.py missing)"

# ── PHASE 11: WINDOWS BINARIES ───────────────────────────────────────────────
section "Phase 11 — Windows Binaries"
WIN="$HOME/tools/windows"
file "$WIN/SharpHound.exe"      "SharpHound.exe"
file "$WIN/Rubeus.exe"          "Rubeus.exe"
file "$WIN/Seatbelt.exe"        "Seatbelt.exe"
file "$WIN/PowerView.ps1"       "PowerView.ps1"
file "$WIN/Certify.exe"         "Certify.exe"
file "$WIN/PrintSpoofer64.exe"  "PrintSpoofer64.exe"
file "$WIN/GodPotato-NET4.exe"  "GodPotato-NET4.exe"
file "$WIN/SharpDPAPI.exe"      "SharpDPAPI.exe"
file "$WIN/mimikatz.exe"        "mimikatz.exe"
file "$WIN/chisel.exe"          "chisel.exe"
file "$WIN/nc.exe"              "nc.exe"

# ── PHASE 12: CUSTOM ENVIRONMENT ─────────────────────────────────────────────
section "Phase 12 — Custom Environment"
if source "$HOME/.shellshock_env" 2>/dev/null; then
    # Verify key impacket aliases resolved
    for a in secretsdump GetNPUsers GetUserSPNs getTGT getST smbserver psexec wmiexec; do
        command -v "$a" &>/dev/null && pass "alias: $a" || fail "alias: $a not available (source ~/.shellshock_env)"
    done
else
    fail "~/.shellshock_env failed to source"
fi

# ── PHASE 16: CLAUDE CODE ─────────────────────────────────────────────────────
section "Phase 16 — Claude Code"
cmd claude
[[ -f "$HOME/Desktop/CLAUDE.md" ]] && pass "CLAUDE.md present" \
    || warn "CLAUDE.md missing from ~/Desktop"

# ── SUMMARY ──────────────────────────────────────────────────────────────────
TOTAL=$((PASS + FAIL + WARN))
echo ""
echo -e "${BOLD}────────────────────────────────────${NC}"
echo -e "${BOLD}$TOTAL checks${NC}"
echo -e "  ${GREEN}Pass:${NC}  $PASS"
echo -e "  ${YELLOW}Warn:${NC}  $WARN"
echo -e "  ${RED}Fail:${NC}  $FAIL"
echo -e "${BOLD}────────────────────────────────────${NC}"

[[ $FAIL -gt 0 ]] \
    && echo -e "\n${RED}Incomplete. Review FAILs above.${NC}" && exit 1 \
    || echo -e "\n${GREEN}All checks passed.${NC}" && exit 0
