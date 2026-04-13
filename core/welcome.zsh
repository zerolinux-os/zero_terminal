# =============================================================================
# ZeroLinux Welcome Screen — shown once per new terminal
# Guarded by ZL_WELCOMED — never runs more than once per session.
# =============================================================================
[[ $- != *i* ]] && return 0

_zl_print_welcome() {
  local reset='\033[0m' bold='\033[1m'
  local blue='\033[1;34m' cyan='\033[0;36m'
  local green='\033[0;32m' yellow='\033[1;33m'
  local red='\033[1;31m' dim='\033[2;37m'

  local ver
  ver=$(cat "$ZL_HOME/VERSION" 2>/dev/null || echo "2.0.0")

  printf "\n${blue}${bold}"
  printf "  ______               _      _\n"
  printf " |___  /              | |    (_)\n"
  printf "    / /  ___ _ __ ___ | |     _ _ __  _  _\n"
  printf "   / /  / _ \\ '__/ _ \\| |    | | '_ \\| | | |\n"
  printf "${red}${bold}"
  printf "  / /__|  __/ | | (_) | |____| | | | | |_| |\n"
  printf " /_____/\\___|_|  \\___/|______|_|_| |_|\\__,_|\n"
  printf "${reset}"
  printf "  ${dim}Terminal Framework v%s${reset}\n\n" "$ver"

  # Quick stats
  local plugin_count=0
  [[ -d "${ZL_PLUGINS_DIR:-}" ]] && \
    plugin_count=$(find "$ZL_PLUGINS_DIR" -name 'init.zsh' 2>/dev/null | wc -l | tr -d ' ')

  printf "  ${cyan}%-14s${reset}%s\n" "Plugins:" "$plugin_count loaded"
  printf "  ${cyan}%-14s${reset}%s\n" "Shell:"   "zsh $ZSH_VERSION"
  printf "  ${cyan}%-14s${reset}%s\n" "Help:"    "zl help  |  zl doctor"
  printf "\n"
}

_zl_print_welcome
unfunction _zl_print_welcome 2>/dev/null || true
