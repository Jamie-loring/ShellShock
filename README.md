# ShellShock v2.4

**Repository:** [Jamie-loring/ShellShock](https://github.com/Jamie-loring/main/blob/main/README.md)

---

## Overview

ShellShock is an automated pentest environment bootstrap script for **Debian-based** systems. It transforms a fresh install into a complete, production-ready penetration testing box — all with a single command.

```bash
curl -fsSL https://raw.githubusercontent.com/Jamie-loring/main/main/install.sh -o /tmp/shellshock.sh
sudo bash /tmp/shellshock.sh
```

**The structure is:**
```
https://raw.githubusercontent.com/
  Jamie-loring/           (user)
  Public-scripts/         (repo)
  main/               (branch)
  install.sh              (filename)
```

After installation, **reboot** when prompted, then run `~/.config/htb-terminal-setup.sh` to activate terminal colors.

---

## Installation Phases

ShellShock runs through 15 phases automatically:

| Phase | Description |
|-------|-------------|
| 1 | System preparation, time sync (chrony), package updates |
| 2 | VirtualBox Guest Additions (auto-detected) |
| 3 | Core packages (~50 packages) |
| 4 | User account creation, sudo config, directory structure |
| 5 | Go 1.23.3 installation with system-wide PATH config |
| 6 | Shell configuration — ZSH removal, Bash with HTB Pwnbox theme |
| 7 | Python tools (pip + pipx) |
| 8 | Ruby tools (gem) |
| 9 | Go security tools |
| 10 | Repositories, wordlists, quick-access scripts |
| 11 | Windows binaries |
| 12 | Custom environment file (~/.shellshock_env) with all aliases |
| 13 | Documentation & supplemental scripts |
| 14 | Desktop theme & appearance |
| 15 | Final system configuration, disable default 'user' account |
| 16 | Claude Code CLI installation + default CLAUDE.md |
| 17 | Completion summary & reboot prompt |

---

## What Gets Installed

### Core System Packages

```
curl, wget, git, vim, nano, unzip, p7zip-full, tmux,
build-essential, gcc, g++, make, cmake, pkg-config,
python3, python3-pip, python3-venv, pipx,
ruby, ruby-dev,
nmap, masscan, netcat-traditional, socat, tcpdump, wireshark, tshark,
dnsutils, whois, host, ldap-utils, openssl,
nikto, dirb, wfuzz, sqlmap,
john, hashcat, hydra, nfs-common, snmp, ftp,
exploitdb, metasploit-framework,
smbclient, cifs-utils,
pass                    # GPG-encrypted credential storage
```

### Go Security Tools (1.23.3)

Installed to `~/go/bin/`, all in PATH automatically:

| Tool | Purpose |
|------|---------|
| httpx | HTTP probing and analysis |
| subfinder | Subdomain discovery |
| dnsx | DNS query toolkit |
| nuclei | Vulnerability scanner with templates |
| ffuf | Web fuzzer |
| gobuster | Directory/DNS/vhost brute-forcing |
| kerbrute | Kerberos brute-forcing |
| chisel | TCP/UDP tunneling over HTTP |
| ligolo-ng | Tunneling/pivoting proxy |
| interactsh-client | OOB interaction detection (free Burp Collaborator) |
| katana | Web crawler (JS-aware, ProjectDiscovery) |
| naabu | Fast port scanner (ProjectDiscovery suite) |
| gf | Pattern matching / grep on steroids for recon |
| anew | Append-new-lines deduplication tool |

### Python Tools

**System-wide (pip3):**
```
impacket, bloodhound, bloodyAD, mitm6, netexec
pwntools, pycryptodome, scapy        # binary exploitation & crypto
playwright                           # browser automation (XSS/SSRF challenges)
flask, paramiko, requests, httpx     # web & networking
PyJWT, pyOpenSSL, beautifulsoup4     # auth & parsing
mcp                                  # Model Context Protocol SDK
python-dotenv
```

**Isolated (pipx):**
```
ldapdomaindump, sprayhound, certipy-ad
crackmapexec
ROPgadget, ropper                    # binary exploitation
```

### Ruby Tools

```
evil-winrm, one_gadget, haiti-hash
```

### Windows Binaries

Pre-downloaded to `~/tools/windows/`:

| Binary | Purpose |
|--------|---------|
| SharpHound.exe | BloodHound collector |
| Seatbelt.exe | Windows enumeration |
| Rubeus.exe | Kerberos abuse toolkit |
| PowerView.ps1 | AD enumeration |
| Certify.exe | ADCS certificate exploitation |
| KrbRelayUp.exe | Kerberos relay privilege escalation |
| PrintSpoofer64.exe | Printer spooler token impersonation |
| GodPotato.exe | Potato-family token impersonation |
| mimikatz.exe | Credential extraction |
| chisel.exe | TCP/UDP tunnel (Windows client) |
| nc.exe | Netcat for Windows |

### Quick-Access Scripts

Downloaded to `~/tools/scripts/`:

| Script | Purpose |
|--------|---------|
| linpeas.sh | Linux privilege escalation scanner |
| winpeas.exe | Windows privilege escalation scanner |
| penelope.py | Advanced reverse shell handler |
| pspy64 | Linux process monitor without root |
| stegseek | Fast steghide bruteforcer |
| rustscan | Ultra-fast port scanner |
| feroxbuster | Recursive web content discovery |

### Repositories

Auto-cloned to `~/tools/repos/`:

```
SecLists              # Comprehensive wordlist collection
penelope              # Reverse shell handler
PayloadsAllTheThings  # Payload reference
Responder             # LLMNR/NBT-NS/mDNS poisoner
enum4linux-ng         # SMB/LDAP enumeration
PEASS-ng              # Source for linpeas/winpeas updates
pwndbg                # GDB enhanced features for binary exploitation
```

### Wordlists

* **SecLists** — complete collection (symlinked to `~/wordlists/SecLists`)
* **rockyou.txt** — extracted and ready at `~/wordlists/rockyou.txt`

---

## Core Commands & Aliases

### Impacket Shortcuts

No more `impacket-` prefix:

```bash
secretsdump             # impacket-secretsdump
GetNPUsers              # impacket-GetNPUsers
GetUserSPNs             # impacket-GetUserSPNs
psexec                  # impacket-psexec
wmiexec                 # impacket-wmiexec
dcomexec                # impacket-dcomexec
atexec                  # impacket-atexec
smbexec                 # impacket-smbexec
smbclient               # impacket-smbclient
smbserver               # impacket-smbserver
GetADUsers              # impacket-GetADUsers
GetADComputers          # impacket-GetADComputers
getTGT                  # impacket-getTGT
getST                   # impacket-getST
ticketer                # impacket-ticketer
lookupsid               # impacket-lookupsid
reg                     # impacket-reg
rpcdump                 # impacket-rpcdump
samrdump                # impacket-samrdump
```

### Tool Shortcuts

```bash
responder               # Responder.py from ~/tools/repos/
enum4linux-ng           # enum4linux-ng.py
penelope                # ~/tools/scripts/penelope.py
linpeas                 # ~/tools/scripts/linpeas.sh
winpeas                 # ~/tools/scripts/winpeas.exe
john                    # /usr/sbin/john (mapped to PATH)
```

### HTB Workflow

```bash
htb-new machine         # Create new engagement directory structure
htb machine             # Navigate to engagement directory
htb-list                # List all engagements
```

Auto-creates:
```
~/engagements/machine/
├── nmap/
├── loot/
├── exploit/
└── www/
```

### Network & Recon

```bash
sweep 10.10.10.0/24     # Quick ping sweep
portscan <target>       # Fast full port scan (-p- -T4 --min-rate 1000)
dirscan <url>           # Directory brute-force with gobuster
myip                    # Show network interfaces
htbip                   # Show HTB VPN IP (tun0)
vpncheck                # Check VPN connection status
ports                   # netstat -tulanp
listening               # ss -tulpn
```

### File Operations

```bash
serve [port]            # Quick HTTP server (default: 8000)
smbserve [share] [path] # Quick SMB server with impacket
extract <file>          # Universal archive extractor
```

### System Aliases

```bash
# Navigation
ll, la, l               # ls variants
.., ..., ....           # cd up directories
home, ~                 # cd home

# History
h                       # history
hg                      # history | grep

# Files
c                       # clear
count                   # wc -l
mkdir                   # mkdir -pv (auto-create parents)
df, du, free            # human-readable by default
path                    # show PATH one per line
now                     # timestamp

# Process
psg                     # ps aux | grep
topcpu                  # top CPU consumers
topmem                  # top memory consumers

# Git
gs, ga, gc, gp          # status, add, commit, push
gl                      # log --oneline --graph
gd                      # diff

# Python
python                  # python3
pip                     # pip3
venv                    # python3 -m venv

# Compression
tarc, tarx, tart        # tar create, extract, list

# Permissions
chmod-x                 # chmod +x
chown-me                # sudo chown -R $USER:$USER

# Safety (interactive prompts)
rm, cp, mv, ln          # -i flag by default
```

---

## Supplemental Scripts

Cloned from the repository to `~/Desktop/ShellShock-Scripts/`:

| Script | Purpose |
|--------|---------|
| end-engagement.sh | Archive engagement data, reset configs, clear credentials |
| tools-update.sh | Update Git repos, Go tools, and specific tools (nuclei, msf, searchsploit) |
| shellshock-darkmode.sh | Apply system-wide dark mode |

### Post-Clone Fixes

The installer automatically patches supplemental scripts after cloning:

* **end-engagement.sh** — filename spaces removed (prevents `bash: ./: Is a directory` errors)
* **end-engagement.sh** — Firefox saved passwords/credentials cleanup added (`logins.json`, `key4.db`, `signons.sqlite`)
* **tools-update.sh** — `TOOLS_DIR` corrected to `~/tools/repos/` to match actual directory structure

### End Engagement Cleanup

`end-engagement.sh` archives and resets between engagements:

**Archives:** engagement directories, bash history, /etc/hosts, Kerberos config, proxychains config, SSH known_hosts, Kerberos tickets, Burp/ZAP state, BloodHound data, Responder logs, nmap scans

**Resets:** /etc/hosts, /etc/krb5.conf, proxychains, shell history, temp files, system logs

**Clears:** Firefox cookies, saved usernames/passwords, form history, session data, cached credentials (NetExec, CrackMapExec)

### Tools Updater

`tools-update.sh` provides interactive or automated updates:

```bash
./tools-update.sh              # Interactive menu
./tools-update.sh -a           # Auto-update everything
./tools-update.sh -g           # Git repos only
./tools-update.sh --go-only    # Go tools only
./tools-update.sh -s           # Specific tools (nuclei templates, msf, searchsploit)
```

---

## Shell Environment

### Bash Configuration

* ZSH fully purged (causes command truncation during engagements)
* HTB Pwnbox-style two-line prompt: `┌──(user㉿hostname)-[~/path]` / `└─$`
* Extended history: 10,000 lines, deduplication, append mode
* HTB color scheme: green directories, cyan executables
* Custom dircolors for consistent theming

### Terminal Profile

After first login, run:

```bash
~/.config/htb-terminal-setup.sh
```

Creates an "HTB Pwnbox" terminal profile with:
* Dark background (`#0a0e14`)
* Green text (`#9fef00`)
* HTB color palette
* Monospace 11pt font

**MATE Terminal (Parrot OS):** Right-click → Profiles → ShellShock

**GNOME Terminal:** Set as default automatically

---

## Directory Structure

```
~/
├── engagements/              # Pentest engagement directories
├── tools/
│   ├── repos/                # Git clones (SecLists, PEASS, PayloadsAllTheThings, penelope)
│   ├── scripts/              # Quick-access scripts (linpeas, winpeas, penelope)
│   └── windows/              # Windows binaries (Rubeus, SharpHound, Seatbelt, PowerView)
├── wordlists/
│   ├── SecLists -> ~/tools/repos/SecLists
│   └── rockyou.txt
├── go/bin/                   # Go tools (httpx, nuclei, ffuf, gobuster, etc.)
├── Desktop/
│   ├── SHELLSHOCK-DOCS/      # Reference documentation
│   └── ShellShock-Scripts/   # Supplemental utilities
└── .config/
    └── htb-terminal-setup.sh # Terminal color installer
```

### Documentation

```
~/Desktop/SHELLSHOCK-DOCS/
├── ALIASES.txt               # Complete alias reference
├── HTB-WORKFLOW.txt          # Engagement workflow guide
├── IMPACKET.txt              # Impacket tools quick reference
├── TOOLS.txt                 # Installed tools and locations
└── QUICK-START.txt           # Getting started guide
```

---

## VirtualBox Integration

* Auto-detects Oracle VirtualBox guests via `dmidecode` and `lspci`
* Downloads and installs matching Guest Additions ISO
* Fallback to v7.1.4 if version detection fails
* Enables clipboard sharing, drag & drop, shared folders

---

## User Account Setup

* Prompts for a dedicated pentesting username (default: current user or `pentester`)
* Validates against reserved system names (root, daemon, user, www-data, etc.)
* Creates account with sudo + docker group membership
* Configures passwordless sudo
* Disables Parrot's default `user` account (locked, expired, nologin shell, hidden from display manager)

---

## Supported Systems

Tested and optimized for:

* **Parrot Security OS** (Debian-based, preferred)
* **Kali Linux** (Debian-based)
* Other Debian-based distributions

---

## Smart Detection

ShellShock won't reinstall what's already there:

* Checks for existing packages before installing
* Skips already-cloned Git repositories
* Detects existing Go installation
* Verifies user account before creating
* Checks for existing VirtualBox Guest Additions

---

## Changelog

### v2.4 (March 2026)
* Added Claude Code CLI installation (Phase 15.5) with default CLAUDE.md template
* Added `pass` to CORE_PACKAGES for GPG-encrypted credential storage
* Added `mcp` (Model Context Protocol Python SDK) to Python tools
* README: added MCP, Ghost Browser VM, and Claude Code sections

### v2.3 (February 2026)
* Fixed `end engagement.sh` filename (space → hyphen) via post-clone patch
* Fixed `tools-update.sh` TOOLS_DIR path to match `~/tools/repos/`
* Added Firefox saved password cleanup to end-engagement.sh (`logins.json`, `key4.db`, `signons.sqlite`)
* Added `john` alias mapping to `/usr/sbin/john` (not in user PATH on Debian)
* Removed duplicate `john` entry from CORE_PACKAGES

### v2.2 (December 2025)
* 15-phase installation pipeline
* HTB Pwnbox terminal color scheme
* Comprehensive alias system
* Supplemental scripts auto-clone from GitHub
* VirtualBox Guest Additions auto-detection and install
* Default 'user' account disable for Parrot OS
* Documentation generation

---



---

## MCP (Model Context Protocol)

The MCP Python SDK (`pip3 install mcp`) ships as part of the ShellShock Python stack.

**Dedicated repo:** [Jamie-loring/claude-mcp](https://github.com/Jamie-loring/claude-mcp)

Includes configuration reference, CLAUDE.md guide, persistent memory docs, and ready-to-use example servers (pentest tools wrapper, engagement notes server).

---

---

## Ghost Browser VM

Ghost is a containerised Chromium automation platform for covert web operations.

**Dedicated repo:** [Jamie-loring/ghost-vm](https://github.com/Jamie-loring/ghost-vm)

Includes full source (Dockerfile, API, human-paced interaction layer), deploy instructions, volume backup/restore guide, and API reference.

---

---

## Claude Code

Claude Code is Anthropic's AI CLI for software engineering and automation, running natively in the terminal alongside your pentesting workflow.

### Installation

ShellShock now installs Claude Code automatically. Manual install:

```bash
npm install -g @anthropic-ai/claude-code
# or
curl -fsSL https://claude.ai/install.sh | sh
```

### Settings

`~/.claude/settings.json` — global configuration:

```json
{
  "autoApproveTools": ["bash"],
  "skipDangerousModePermissionPrompt": true,
  "mcpServers": {},
  "hooks": {}
}
```

### Hooks

Hooks intercept tool calls before or after execution — useful for guardrails, logging, or enforcement:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [{
        "type": "command",
        "command": "INPUT=$(cat); CMD=$(echo \"$INPUT\" | jq -r '.tool_input.command // empty'); if echo \"$CMD\" | grep -q 'pattern-to-block'; then echo '{\"continue\":false,\"stopReason\":\"Blocked: reason\"}'  ; fi"
      }]
    }]
  }
}
```

### CLAUDE.md

Drop a `CLAUDE.md` in any project directory to give Claude standing instructions for that context. Claude Code reads all CLAUDE.md files from the working directory up to `~/`:

```markdown
# Project — Standing Instructions

## Autonomy
Claude can freely modify files and run commands in this project.
No need to ask before editing, rebuilding, or restarting services.

## Constraints
- Never commit credentials to git
- Back up browser-profile volume before any destructive container action

## Context
<project-specific knowledge — architecture, quirks, important paths>
```

### Persistent Memory

Claude Code stores structured memory across sessions at:
```
~/.claude/projects/<working-dir-hash>/memory/
├── MEMORY.md           — index file (loaded every session)
├── user_profile.md     — who you are, preferences
├── feedback_*.md       — corrections and validated approaches
├── project_*.md        — active project state and goals
└── reference_*.md      — pointers to external systems
```

Memory types: `user`, `feedback`, `project`, `reference`. Claude reads these automatically and writes new entries as it learns your workflow.

### MCP Integration

See the [MCP section](#mcp-model-context-protocol) above. MCP servers registered in `~/.claude/settings.json` are available as native tools in every Claude Code session.

---

## Legal & Ethics

> *"Just because you can, doesn't mean you should."*

* Always get explicit permission before testing
* Stay within scope
* Be ethical, responsible, and lawful

This script is **100% free** to modify and distribute — but you **cannot charge** for it.

---

**Author:** Jamie Loring
**Last Updated:** March 2026
