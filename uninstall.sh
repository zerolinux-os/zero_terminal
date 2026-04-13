#!/usr/bin/env bash
# =============================================================================
# ZeroLinux Terminal Framework v2 — uninstall.sh
# =============================================================================
set -uo pipefail

ZL_HOME="${ZL_HOME:-$HOME/.zerolinux}"
ZL_ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
ZL_LOCAL_BIN="$HOME/.local/bin/zl"

C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'
C_CYAN=$'\033[0;36m'; C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'

_ok()   { printf "  ${C_GREEN}✓${C_RESET}  %s\n" "$*"; }
_warn() { printf "  ${C_YELLOW}!${C_RESET}  %s\n" "$*"; }
_err()  { printf "  ${C_RED}✗${C_RESET}  %s\n" "$*"; }
_info() { printf "  ${C_CYAN}→${C_RESET}  %s\n" "$*"; }

printf "\n${C_RED}${C_BOLD}ZeroLinux Uninstaller${C_RESET}\n\n"

printf "  ${C_YELLOW}!${C_RESET}  This will remove ZeroLinux from your system.\n"
printf "  Continue? [y/N] "
read -r reply
[[ "$reply" =~ ^[Yy]$ ]] || { _info "Aborted."; exit 0; }

# Backup .zshrc first
if [[ -f "$ZL_ZSHRC" ]]; then
  cp "$ZL_ZSHRC" "${ZL_ZSHRC}.pre-uninstall-$(date +%s)" 2>/dev/null && \
    _ok "Backed up: $ZL_ZSHRC"
fi

# Remove ZeroLinux block from .zshrc
if [[ -f "$ZL_ZSHRC" ]]; then
  _zl_tmp=$(mktemp)
  awk '
    /# >>> ZEROLINUX START >>>/{skip=1}
    !skip{print}
    /# <<< ZEROLINUX END <<</  {skip=0}
  ' "$ZL_ZSHRC" > "$_zl_tmp" && mv "$_zl_tmp" "$ZL_ZSHRC"
  _ok "Removed ZeroLinux block from .zshrc"
fi

# Remove symlink
if [[ -L "$ZL_LOCAL_BIN" ]]; then
  rm "$ZL_LOCAL_BIN" && _ok "Removed symlink: $ZL_LOCAL_BIN"
fi

# Remove ZL_HOME
if [[ -d "$ZL_HOME" ]]; then
  rm -rf "$ZL_HOME" && _ok "Removed: $ZL_HOME"
fi

printf "\n  ${C_GREEN}${C_BOLD}ZeroLinux uninstalled.${C_RESET}\n"
printf "  Restart your shell: ${C_CYAN}exec zsh${C_RESET}\n\n"
