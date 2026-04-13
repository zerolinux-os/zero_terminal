#!/usr/bin/env bash
# =============================================================================
# ZeroLinux Terminal Framework v2 — install.sh
#
# SAFETY CONTRACT (in order of enforcement):
#   1. check_prerequisites()  — runs BEFORE any file is touched
#   2. create_backup()        — runs BEFORE anything is modified
#   3. write_restore_script() — rollback is ALWAYS available
#   4. inject_zshrc()         — NEVER overwrites .zshrc; uses guarded block
#   5. ERR trap               — auto-rollback on unexpected failure
#   6. Every destructive step is reversible
#
# Non-interactive: NONINTERACTIVE=1 bash install.sh
#                  bash install.sh --yes
# =============================================================================
set -uo pipefail
# Note: NOT set -e — we handle errors explicitly with traps and checks.
# set -e causes issues with (( )) arithmetic and conditional assignments.

# ── Identity ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZL_REPO_DIR="$SCRIPT_DIR"

# ── Config ────────────────────────────────────────────────────────────────────
ZL_HOME="${ZL_HOME:-$HOME/.zerolinux}"
ZL_VERSION="$(cat "$ZL_REPO_DIR/VERSION" 2>/dev/null || echo "2.1.1")"
ZL_BACKUP_DIR="${HOME}/.zerolinux_backup/$(date +%Y%m%d_%H%M%S)"
ZL_LOG_DIR="${ZL_HOME}/logs"
ZL_LOG="${ZL_LOG_DIR}/install.log"
ZL_ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"

NONINTERACTIVE="${NONINTERACTIVE:-0}"
ZL_YES=0
ZL_DRY_RUN=0
_ZL_INSTALL_FAILED=0
_ZL_BACKUP_DONE=0
INSTALL_OMZ=0             # Requires --with-ohmyzsh; NOT set by --yes
ZL_EXIT_CODE=0          # Set to 1 on any fatal error; read by final guard

# ── Color (always — installer runs in terminal) ───────────────────────────────
C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
C_BLUE=$'\033[1;34m'; C_CYAN=$'\033[0;36m'; C_GREEN=$'\033[0;32m'
C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_WHITE=$'\033[1;37m'
C_DIM=$'\033[2;37m'

# ── Output ────────────────────────────────────────────────────────────────────
_ok()      { printf "  ${C_GREEN}✓${C_RESET}  %s\n"      "$*"; _flog "OK: $*"; }
_warn()    { printf "  ${C_YELLOW}!${C_RESET}  %s\n"     "$*"; _flog "WARN: $*"; }
_err()     { printf "  ${C_RED}✗${C_RESET}  %s\n"        "$*" >&2; _flog "ERROR: $*"; }
_info()    { printf "  ${C_CYAN}→${C_RESET}  %s\n"       "$*"; _flog "INFO: $*"; }
_step()    { printf "\n${C_BLUE}${C_BOLD}━━━ %s ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n" "$*"; }
_flog()    {
  mkdir -p "$ZL_LOG_DIR" 2>/dev/null || true
  printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$ZL_LOG" 2>/dev/null || true
}

# ── Banner ────────────────────────────────────────────────────────────────────
_banner() {
  printf "\n"
  printf "${C_BLUE}${C_BOLD}"
  printf " ______               _      _\n"
  printf "|___  /              | |    (_)\n"
  printf "   / /  ___ _ __ ___ | |     _ _ __  _  _\n"
  printf "  / /  / _ \\'__/ _ \\| |    | | '_ \\| | | |\n"
  printf "${C_RED}${C_BOLD}"
  printf " / /__|  __/ | | (_) | |____| | | | | |_| |\n"
  printf "/_____/\\___|_|  \\___/|______|_|_| |_|\\__,_|\n"
  printf "${C_RESET}\n"
  printf "  ${C_WHITE}Terminal Framework Installer${C_RESET}  ${C_DIM}v%s${C_RESET}\n\n" "$ZL_VERSION"
}

# ── Parse args ────────────────────────────────────────────────────────────────
_parse_args() {
  for arg in "$@"; do
    case "$arg" in
      --yes|-y)          ZL_YES=1; NONINTERACTIVE=1 ;;
      --dry-run|-n)      ZL_DRY_RUN=1 ;;
      --with-ohmyzsh)    INSTALL_OMZ=1 ;;
      --help|-h)         _banner; _usage; exit 0 ;;
    esac
  done
}

_usage() {
  printf "Usage: bash install.sh [--yes] [--dry-run] [--with-ohmyzsh] [--help]\n\n"
  printf "  --yes, -y        Skip all confirmation prompts\n"
  printf "  --dry-run, -n    Show what would happen without doing it\n"
  printf "  --with-ohmyzsh   Also install Oh My Zsh (not installed by default)\n"
  printf "  --help, -h       Show this help\n\n"
  printf "Env vars:\n"
  printf "  NONINTERACTIVE=1  Same as --yes\n"
  printf "  ZL_HOME=<path>    Override install location (default: ~/.zerolinux)\n\n"
}

# ── Confirmation ──────────────────────────────────────────────────────────────
_confirm() {
  local prompt="${1:-Continue?}"
  if (( NONINTERACTIVE || ZL_YES )); then
    _info "$prompt [auto-yes]"
    return 0
  fi
  printf "  ${C_YELLOW}?${C_RESET}  %s [y/N] " "$prompt"
  local reply
  read -r reply
  [[ "$reply" =~ ^[Yy]$ ]] || { _info "Skipped."; return 1; }
}

# ── ERR trap / rollback ───────────────────────────────────────────────────────
# BUG-14 FIX: Previous version passed $? as argument to _on_error and re-used
# it in exit "$exit_code". This is fragile: $? can be corrupted when the failing
# command runs inside a subshell or process substitution (e.g. exec > >(tee ...)).
# Fix: _on_error always exits 1. Line number still logged for debugging.
# ZL_EXIT_CODE is set to 1 before exit for the final guard in main().
_on_error() {
  local line_no="${LINENO:-?}"
  _ZL_INSTALL_FAILED=1
  ZL_EXIT_CODE=1

  printf "\n" >&2
  _err "Installation failed at line ${line_no}"
  _err "Log: $ZL_LOG"

  if (( _ZL_BACKUP_DONE )); then
    printf "\n" >&2
    printf "  ${C_YELLOW}${C_BOLD}Recovery:${C_RESET}\n" >&2
    printf "  Backup:  ${C_WHITE}%s${C_RESET}\n" "$ZL_BACKUP_DIR" >&2
    if [[ -f "$ZL_BACKUP_DIR/restore.sh" ]]; then
      printf "  Restore: ${C_WHITE}bash %s/restore.sh${C_RESET}\n" \
        "$ZL_BACKUP_DIR" >&2
    fi
  fi
  printf "\n" >&2

  # Always exit 1 — deterministic, immune to $? subshell corruption
  exit 1
}

trap '_on_error' ERR

# ── Prerequisites check ───────────────────────────────────────────────────────
check_prerequisites() {
  _step "Checking Prerequisites"
  local issues=0

  # zsh
  if ! command -v zsh &>/dev/null; then
    _err "zsh is required but not found"
    _err "  Arch:   sudo pacman -S zsh"
    _err "  Debian: sudo apt-get install zsh"
    issues=$(( issues + 1 ))
  else
    local zsh_ver
    zsh_ver=$(zsh --version 2>/dev/null | awk '{print $2}')
    _ok "zsh $zsh_ver  ($(command -v zsh))"
    # Require zsh >= 5.3
    local major minor
    major="${zsh_ver%%.*}"
    minor="${zsh_ver#*.}"; minor="${minor%%.*}"
    if (( major < 5 || (major == 5 && minor < 3) )); then
      _warn "zsh $zsh_ver < 5.3 — some features may not work"
    fi
  fi

  # git
  if ! command -v git &>/dev/null; then
    _err "git is required but not found"
    issues=$(( issues + 1 ))
  else
    _ok "git $(git --version | awk '{print $3}')"
  fi

  # curl or wget (for optional downloads)
  if command -v curl &>/dev/null; then
    _ok "curl $(curl --version | head -1 | awk '{print $2}')"
  elif command -v wget &>/dev/null; then
    _ok "wget (curl preferred but wget available)"
  else
    _warn "curl/wget not found — network features unavailable"
  fi

  # Write permission to HOME
  if [[ ! -w "$HOME" ]]; then
    _err "HOME directory is not writable: $HOME"
    issues=$(( issues + 1 ))
  else
    _ok "HOME writable: $HOME"
  fi

  # Disk space (require at least 100MB free)
  local free_kb
  free_kb=$(df -k "$HOME" 2>/dev/null | awk 'NR==2{print $4}' || echo 999999)
  if (( free_kb < 102400 )); then
    _warn "Low disk space: $(( free_kb / 1024 ))MB free (100MB recommended)"
  else
    _ok "Disk space: $(( free_kb / 1024 ))MB free"
  fi

  # Not running as root
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    _warn "Running as root — ZeroLinux installs per-user, this may cause permission issues"
  fi

  if (( issues > 0 )); then
    _err "${issues} prerequisite(s) failed — aborting"
    exit 1
  fi

  _ok "All prerequisites satisfied"
}

# ── Backup ────────────────────────────────────────────────────────────────────
create_backup() {
  _step "Creating Backup"

  mkdir -p "$ZL_BACKUP_DIR" || {
    _err "Cannot create backup directory: $ZL_BACKUP_DIR"
    exit 1
  }
  _ZL_BACKUP_DONE=1
  _info "Backup location: $ZL_BACKUP_DIR"

  # Backup .zshrc
  if [[ -f "$ZL_ZSHRC" ]]; then
    cp -a "$ZL_ZSHRC" "$ZL_BACKUP_DIR/zshrc.bak" || {
      _err "Failed to backup $ZL_ZSHRC"
      exit 1
    }
    _ok "Backed up: $ZL_ZSHRC"
  else
    _info ".zshrc does not exist yet — will be created"
  fi

  # Backup existing ZL_HOME
  if [[ -d "$ZL_HOME" ]]; then
    cp -a "$ZL_HOME" "$ZL_BACKUP_DIR/zerolinux_home.bak" || {
      _err "Failed to backup $ZL_HOME"
      exit 1
    }
    _ok "Backed up: $ZL_HOME"
  fi

  # Write restore script
  write_restore_script
  _ok "Restore script: $ZL_BACKUP_DIR/restore.sh"
}

write_restore_script() {
  cat > "$ZL_BACKUP_DIR/restore.sh" << RESTORE
#!/usr/bin/env bash
# ZeroLinux restore script — auto-generated by install.sh
# Run: bash "$ZL_BACKUP_DIR/restore.sh"
set -euo pipefail

BACKUP_DIR="$ZL_BACKUP_DIR"
ZL_HOME="$ZL_HOME"
ZL_ZSHRC="$ZL_ZSHRC"

echo "ZeroLinux Restore — from: \$BACKUP_DIR"

# Restore .zshrc
if [[ -f "\$BACKUP_DIR/zshrc.bak" ]]; then
  cp -a "\$BACKUP_DIR/zshrc.bak" "\$ZL_ZSHRC"
  echo "  ✓ Restored: \$ZL_ZSHRC"
fi

# Restore ZL_HOME
if [[ -d "\$BACKUP_DIR/zerolinux_home.bak" ]]; then
  rm -rf "\$ZL_HOME"
  cp -a "\$BACKUP_DIR/zerolinux_home.bak" "\$ZL_HOME"
  echo "  ✓ Restored: \$ZL_HOME"
elif [[ -d "\$ZL_HOME" ]]; then
  echo "  → No ZL_HOME backup (it was not installed before) — removing"
  rm -rf "\$ZL_HOME"
fi

echo ""
echo "  Restore complete. Restart your shell."
RESTORE
  chmod +x "$ZL_BACKUP_DIR/restore.sh"
}

# ── Install ZL files ──────────────────────────────────────────────────────────
install_framework() {
  _step "Installing ZeroLinux Framework"

  if (( ZL_DRY_RUN )); then
    _info "[DRY RUN] Would install to: $ZL_HOME"
    return 0
  fi

  # Create directory structure
  local -a dirs=(
    "$ZL_HOME"
    "$ZL_HOME/core"
    "$ZL_HOME/config"
    "$ZL_HOME/plugins"
    "$ZL_HOME/themes"
    "$ZL_HOME/bin"
    "$ZL_HOME/logs"
    "$ZL_HOME/assets"
  )
  local d
  for d in "${dirs[@]}"; do
    mkdir -p "$d" || { _err "Cannot create: $d"; exit 1; }
  done
  _ok "Directory structure created"

  # Copy core files
  local -a core_files=(
    core/loader.zsh
    core/logger.zsh
    core/utils.zsh
    core/plugin_manager.zsh
    core/config.zsh
  )
  local f
  for f in "${core_files[@]}"; do
    if [[ -f "$ZL_REPO_DIR/$f" ]]; then
      cp "$ZL_REPO_DIR/$f" "$ZL_HOME/$f" || { _err "Failed to copy $f"; exit 1; }
      _ok "Installed: $f"
    else
      _warn "Source file missing: $ZL_REPO_DIR/$f"
    fi
  done

  # Copy config
  if [[ -f "$ZL_REPO_DIR/config/default.zsh" ]]; then
    cp "$ZL_REPO_DIR/config/default.zsh" "$ZL_HOME/config/default.zsh"
    _ok "Installed: config/default.zsh"
  fi

  # Copy VERSION
  cp "$ZL_REPO_DIR/VERSION" "$ZL_HOME/VERSION" 2>/dev/null || \
    echo "$ZL_VERSION" > "$ZL_HOME/VERSION"
  _ok "Installed: VERSION ($ZL_VERSION)"

  # Copy themes
  if [[ -d "$ZL_REPO_DIR/themes" ]]; then
    cp -r "$ZL_REPO_DIR/themes/." "$ZL_HOME/themes/"
    _ok "Installed: themes/"
  fi

  # Copy assets
  if [[ -d "$ZL_REPO_DIR/assets" ]]; then
    cp -r "$ZL_REPO_DIR/assets/." "$ZL_HOME/assets/"
    _ok "Installed: assets/"
  fi

  # Copy plugins (all subdirs)
  if [[ -d "$ZL_REPO_DIR/plugins" ]]; then
    cp -r "$ZL_REPO_DIR/plugins/." "$ZL_HOME/plugins/"
    _ok "Installed: plugins/"
  fi

  # Install zl binary
  if [[ -f "$ZL_REPO_DIR/bin/zl" ]]; then
    cp "$ZL_REPO_DIR/bin/zl" "$ZL_HOME/bin/zl"
    chmod +x "$ZL_HOME/bin/zl"
    _ok "Installed: bin/zl"
  fi

  # doctor.sh
  if [[ -f "$ZL_REPO_DIR/doctor.sh" ]]; then
    cp "$ZL_REPO_DIR/doctor.sh" "$ZL_HOME/doctor.sh"
    chmod +x "$ZL_HOME/doctor.sh"
    _ok "Installed: doctor.sh"
  fi

  # Create default plugins.conf if not already there
  local conf="$ZL_HOME/core/plugins.conf"
  if [[ ! -f "$conf" ]]; then
    cat > "$conf" << 'CONF'
# ZeroLinux Plugin Configuration — core/plugins.conf
# One plugin name per line. Comment out to disable.
# Manage with: zl enable/disable plugin <name>
git
system
CONF
    _ok "Created: core/plugins.conf (defaults: git, system)"
  else
    _info "plugins.conf already exists — not overwritten"
  fi
}

# ── Symlink zl to PATH ────────────────────────────────────────────────────────
install_symlink() {
  _step "Installing 'zl' to PATH"

  local target="$HOME/.local/bin/zl"
  local source="$ZL_HOME/bin/zl"

  if (( ZL_DRY_RUN )); then
    _info "[DRY RUN] Would symlink: $source → $target"
    return 0
  fi

  mkdir -p "$(dirname "$target")"

  # Remove stale symlink
  if [[ -L "$target" ]]; then
    rm "$target"
  elif [[ -f "$target" ]]; then
    cp "$target" "${target}.bak.$(date +%s)"
    rm "$target"
  fi

  ln -sf "$source" "$target"
  _ok "Symlink: $target → $source"

  # Ensure ~/.local/bin is in PATH for this session
  case ":${PATH}:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
}

# ── .zshrc injection (SAFE — never overwrites) ────────────────────────────────
inject_zshrc() {
  _step "Configuring .zshrc"

  if (( ZL_DRY_RUN )); then
    _info "[DRY RUN] Would inject ZeroLinux block into: $ZL_ZSHRC"
    return 0
  fi

  # Create .zshrc if missing
  if [[ ! -f "$ZL_ZSHRC" ]]; then
    touch "$ZL_ZSHRC" || { _err "Cannot create $ZL_ZSHRC"; exit 1; }
    _info "Created empty: $ZL_ZSHRC"
  fi

  local marker_start="# >>> ZEROLINUX START >>>"
  local marker_end="# <<< ZEROLINUX END <<<"
  local inject_line="source \"\$HOME/.zerolinux/core/loader.zsh\""

  # Build the block content
  local zl_block
  zl_block="${marker_start}
# ZeroLinux Terminal Framework v${ZL_VERSION}
# This block is managed by ZeroLinux install.sh
# DO NOT edit manually — use: zl commands
export ZL_HOME=\"\$HOME/.zerolinux\"
${inject_line}
${marker_end}"

  if grep -qF "$marker_start" "$ZL_ZSHRC" 2>/dev/null; then
    # Block already exists — update it in-place
    _info "ZeroLinux block found in .zshrc — updating"

    # Use Python for reliable multi-line regex replace (Linux + macOS).
    # FIX-09: Pass file path and markers via env vars, not argv, to avoid
    # word-splitting issues with paths containing spaces.
    if command -v python3 &>/dev/null; then
      ZL_ZSHRC_PATH="$ZL_ZSHRC" \
      ZL_MARKER_START="$marker_start" \
      ZL_MARKER_END="$marker_end" \
      ZL_NEW_BLOCK="$zl_block" \
      python3 << 'PYEOF'
import os, re, sys

zshrc_path   = os.environ['ZL_ZSHRC_PATH']
start_marker = os.environ['ZL_MARKER_START']
end_marker   = os.environ['ZL_MARKER_END']
new_block    = os.environ['ZL_NEW_BLOCK']

try:
    with open(zshrc_path, 'r', encoding='utf-8') as f:
        content = f.read()

    pattern = re.escape(start_marker) + r'.*?' + re.escape(end_marker)
    new_content = re.sub(pattern, new_block, content, flags=re.DOTALL)

    # Write atomically via temp file
    tmp_path = zshrc_path + '.zl_tmp'
    with open(tmp_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    os.replace(tmp_path, zshrc_path)
except Exception as e:
    print(f'ZeroLinux: python3 update failed: {e}', file=sys.stderr)
    sys.exit(1)
PYEOF
      _ok "Updated ZeroLinux block in .zshrc"
    else
      # Fallback: delete old block and append new one
      _warn "python3 not found — falling back to block replace"
      local tmp
      tmp=$(mktemp)
      awk "
        /${marker_start//\//\\/}/{skip=1}
        !skip{print}
        /${marker_end//\//\\/}/{skip=0}
      " "$ZL_ZSHRC" > "$tmp" && mv "$tmp" "$ZL_ZSHRC"
      printf '\n%s\n' "$zl_block" >> "$ZL_ZSHRC"
      _ok "Replaced ZeroLinux block in .zshrc"
    fi
  else
    # No block exists — append
    printf '\n%s\n' "$zl_block" >> "$ZL_ZSHRC"
    _ok "ZeroLinux block added to .zshrc"
  fi

  _info "ZL_HOME: $ZL_HOME"
  _info "Loader:  $ZL_HOME/core/loader.zsh"
}

# ── Optional: Oh My Zsh ───────────────────────────────────────────────────────
install_omz() {
  _step "Oh My Zsh (Optional)"

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    _ok "Oh My Zsh already installed"
    return 0
  fi

  _confirm "Install Oh My Zsh? (recommended for themes and completions)" || return 0

  if command -v curl &>/dev/null; then
    RUNZSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      || _warn "Oh My Zsh install failed — continuing without it"
  elif command -v wget &>/dev/null; then
    RUNZSH=no KEEP_ZSHRC=yes \
      sh -c "$(wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      || _warn "Oh My Zsh install failed — continuing without it"
  else
    _warn "curl/wget not available — skipping Oh My Zsh"
  fi
}

# ── Verify installation ───────────────────────────────────────────────────────
verify_install() {
  _step "Verifying Installation"
  local issues=0
  local f

  # Core files
  local -a required_files=(
    "$ZL_HOME/VERSION"
    "$ZL_HOME/core/loader.zsh"
    "$ZL_HOME/core/logger.zsh"
    "$ZL_HOME/core/utils.zsh"
    "$ZL_HOME/core/plugin_manager.zsh"
    "$ZL_HOME/core/config.zsh"
    "$ZL_HOME/bin/zl"
  )
  for f in "${required_files[@]}"; do
    if [[ -f "$f" ]]; then
      _ok "$(basename "$f")"
    else
      _err "MISSING: $f"
      issues=$(( issues + 1 ))
    fi
  done

  # zl is executable
  if [[ ! -x "$ZL_HOME/bin/zl" ]]; then
    _err "bin/zl is not executable"
    issues=$(( issues + 1 ))
  fi

  # .zshrc has the block
  if grep -qF "ZEROLINUX START" "$ZL_ZSHRC" 2>/dev/null; then
    _ok ".zshrc injection present"
  else
    _err ".zshrc injection missing"
    issues=$(( issues + 1 ))
  fi

  if (( issues > 0 )); then
    _err "Verification failed ($issues issues)"
    return 1
  fi
  _ok "Verification passed"
}

# ── Summary ───────────────────────────────────────────────────────────────────
print_summary() {
  printf "\n${C_BLUE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"
  printf "  ${C_GREEN}${C_BOLD}✅  ZeroLinux v%s installed successfully!${C_RESET}\n" "$ZL_VERSION"
  printf "${C_BLUE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n\n"

  printf "  ${C_BOLD}Next steps:${C_RESET}\n"
  printf "  ${C_CYAN}1.${C_RESET} Restart your shell:  ${C_WHITE}exec zsh${C_RESET}\n"
  printf "  ${C_CYAN}2.${C_RESET} Run health check:    ${C_WHITE}zl doctor${C_RESET}\n"
  printf "  ${C_CYAN}3.${C_RESET} View plugins:        ${C_WHITE}zl list plugins${C_RESET}\n"
  printf "  ${C_CYAN}4.${C_RESET} Enable a plugin:     ${C_WHITE}zl enable plugin docker${C_RESET}\n\n"

  printf "  ${C_BOLD}Recovery (if needed):${C_RESET}\n"
  printf "  ${C_DIM}bash %s/restore.sh${C_RESET}\n\n" "$ZL_BACKUP_DIR"

  printf "  ${C_BOLD}Log:${C_RESET} ${C_DIM}%s${C_RESET}\n\n" "$ZL_LOG"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
  _parse_args "$@"
  _banner
  _flog "=== ZeroLinux install.sh v${ZL_VERSION} started ==="

  if (( ZL_DRY_RUN )); then
    printf "  ${C_YELLOW}${C_BOLD}DRY RUN MODE — no files will be modified${C_RESET}\n\n"
  fi

  check_prerequisites
  create_backup
  install_framework
  install_symlink
  inject_zshrc
  (( INSTALL_OMZ )) && install_omz
  verify_install
  print_summary

  _flog "=== install.sh completed successfully ==="
}

main "$@"

# ── Final exit guard ──────────────────────────────────────────────────────────
# BUG-14 FIX: Belt-and-suspenders. If _on_error set ZL_EXIT_CODE=1 but somehow
# the script continued (e.g. ERR trap was temporarily unset by a subshell),
# this ensures we still exit non-zero. On clean success ZL_EXIT_CODE stays 0.
exit "${ZL_EXIT_CODE:-0}"
