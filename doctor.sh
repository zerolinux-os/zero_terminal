#!/usr/bin/env bash
# =============================================================================
# ZeroLinux Terminal Framework v2 — doctor.sh
# Deep diagnostic system. Also callable via: zl doctor
#
# Output format: PASS / WARN / FAIL per check, grouped in sections.
# Exit code: 0 = healthy, 1 = has failures, 2 = has warnings only
#
# CRITICAL: Never use (( issues++ )) under set -eo pipefail.
#           Always use: issues=$(( issues + 1 ))
# =============================================================================
set -uo pipefail
# Not set -e — we want to continue checking after each failure.

ZL_HOME="${ZL_HOME:-$HOME/.zerolinux}"
ZL_PLUGINS_DIR="${ZL_HOME}/plugins"
ZL_CONF="${ZL_HOME}/core/plugins.conf"

# ── Colors ────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_BLUE=$'\033[1;34m'; C_CYAN=$'\033[0;36m'
  C_GREEN=$'\033[0;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'
  C_WHITE=$'\033[1;37m'; C_GRAY=$'\033[2;37m'
else
  # shellcheck disable=SC2034
  C_RESET='' C_BOLD='' C_DIM='' C_BLUE='' C_CYAN=''
  C_GREEN='' C_YELLOW='' C_RED='' C_WHITE='' C_GRAY=''
fi

# ── Counters (NEVER use (( var++ )) under set -e) ─────────────────────────────
total_checks=0
pass_count=0
warn_count=0
fail_count=0

# ── Output primitives ─────────────────────────────────────────────────────────
_pass() {
  printf "  ${C_GREEN}[PASS]${C_RESET} %s\n" "$*"
  pass_count=$(( pass_count + 1 ))
  total_checks=$(( total_checks + 1 ))
}
_warn() {
  printf "  ${C_YELLOW}[WARN]${C_RESET} %s\n" "$*"
  warn_count=$(( warn_count + 1 ))
  total_checks=$(( total_checks + 1 ))
}
_fail() {
  printf "  ${C_RED}[FAIL]${C_RESET} %s\n" "$*" >&2
  fail_count=$(( fail_count + 1 ))
  total_checks=$(( total_checks + 1 ))
}
_info() {
  printf "  ${C_CYAN}[INFO]${C_RESET} %s\n" "$*"
}
_hint() {
  printf "  ${C_DIM}       → %s${C_RESET}\n" "$*"
}
_section() {
  printf "\n${C_BLUE}${C_BOLD}━━━ %s ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n\n" "$*"
}

# ── Helpers ───────────────────────────────────────────────────────────────────
_conf_enabled_plugins() {
  [[ -f "$ZL_CONF" ]] || return 0
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    echo "$line"
  done < "$ZL_CONF"
}

_plugin_meta() {
  local plugin="$1" key="$2"
  local meta="$ZL_PLUGINS_DIR/$plugin/plugin.zl"
  [[ -f "$meta" ]] || { echo ""; return; }
  grep "^${key}[[:space:]]*=" "$meta" 2>/dev/null | head -1 | \
    sed 's/^[^=]*=[[:space:]]*//' | sed 's/[[:space:]]*$//'
}

_check_file() {
  local desc="$1" path="$2" required="${3:-0}"
  if [[ -f "$path" && -r "$path" ]]; then
    _pass "$desc: $path"
    return 0
  elif (( required )); then
    _fail "$desc: MISSING — $path"
    return 1
  else
    _warn "$desc: not found — $path"
    return 1
  fi
}

_check_exec() {
  local desc="$1" path="$2"
  if [[ -f "$path" && -x "$path" ]]; then
    _pass "$desc: $path  [executable]"
    return 0
  elif [[ -f "$path" ]]; then
    _fail "$desc: $path  [NOT executable]"
    _hint "Fix: chmod +x $path"
    return 1
  else
    _fail "$desc: MISSING — $path"
    return 1
  fi
}

_check_dir() {
  local desc="$1" path="$2"
  if [[ -d "$path" ]]; then
    _pass "$desc: $path"
    return 0
  else
    _fail "$desc: MISSING — $path"
    return 1
  fi
}

# =============================================================================
# DIAGNOSTIC SECTIONS
# =============================================================================

# ── 1. System ─────────────────────────────────────────────────────────────────
check_system() {
  _section "System"

  _info "Host:    $(hostname 2>/dev/null || echo unknown)"
  _info "OS:      $(grep PRETTY_NAME /etc/os-release 2>/dev/null | \
                   cut -d= -f2 | tr -d '"' || uname -s)"
  _info "Kernel:  $(uname -r 2>/dev/null || echo unknown)"
  _info "Arch:    $(uname -m 2>/dev/null || echo unknown)"
  _info "Uptime:  $(uptime -p 2>/dev/null | sed 's/up //' || echo unknown)"
  _info "User:    ${USER:-$(id -un)}"
  printf "\n"

  # zsh version
  if command -v zsh &>/dev/null; then
    local zsh_ver
    zsh_ver=$(zsh --version 2>/dev/null | awk '{print $2}')
    local major minor
    major="${zsh_ver%%.*}"
    minor="${zsh_ver#*.}"; minor="${minor%%.*}"
    if (( major > 5 || (major == 5 && minor >= 3) )); then
      _pass "zsh $zsh_ver (>= 5.3 required)"
    else
      _fail "zsh $zsh_ver < 5.3 — upgrade required"
      _hint "Arch: sudo pacman -S zsh  |  Debian: sudo apt-get install --only-upgrade zsh"
    fi
    # Is default shell?
    local default_shell
    default_shell=$(getent passwd "${USER:-root}" 2>/dev/null | cut -d: -f7 || echo "unknown")
    if [[ "$default_shell" == *zsh* ]]; then
      _pass "Default shell: $default_shell"
    else
      _warn "Default shell is not zsh: $default_shell"
      _hint "Fix: chsh -s $(command -v zsh)"
    fi
  else
    _fail "zsh: NOT FOUND"
    _hint "Install: sudo pacman -S zsh  OR  sudo apt-get install zsh"
  fi

  # Disk
  local disk_pct
  disk_pct=$(df / 2>/dev/null | awk 'NR==2{gsub(/%/,"",$5); print $5}' || echo 0)
  if   (( disk_pct > 90 )); then
    _fail "Disk usage: ${disk_pct}% (CRITICAL — clean up immediately)"
    _hint "Run: zl clean  or  sudo journalctl --vacuum-size=200M"
  elif (( disk_pct > 75 )); then
    _warn "Disk usage: ${disk_pct}% (getting full)"
  else
    _pass "Disk usage: ${disk_pct}%"
  fi

  # Memory
  if [[ -f /proc/meminfo ]]; then
    local mem_total mem_avail mem_pct
    mem_total=$(awk '/MemTotal/{print $2}'     /proc/meminfo)
    mem_avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
    mem_pct=$(( (mem_total - mem_avail) * 100 / mem_total ))
    if (( mem_pct > 90 )); then
      _fail "Memory: ${mem_pct}% used (CRITICAL)"
    else
      _pass "Memory: ${mem_pct}% used ($(( mem_avail / 1024 ))MiB free)"
    fi
  fi
}

# ── 2. ZL Installation ────────────────────────────────────────────────────────
check_installation() {
  _section "ZeroLinux Installation"

  # ZL_HOME
  _check_dir "ZL_HOME" "$ZL_HOME" || true

  # VERSION
  if [[ -f "$ZL_HOME/VERSION" ]]; then
    local ver
    ver=$(cat "$ZL_HOME/VERSION" 2>/dev/null || echo "?")
    _pass "VERSION: $ver"
  else
    _warn "VERSION file missing"
  fi

  # Core files (all required)
  local -a core=(loader.zsh logger.zsh utils.zsh plugin_manager.zsh config.zsh)
  local f
  for f in "${core[@]}"; do
    _check_file "core/$f" "$ZL_HOME/core/$f" 1 || true
  done

  # Config
  if [[ -f "$ZL_CONF" ]]; then
    local plugin_lines
    plugin_lines=$(grep -c '^[^#[:space:]]' "$ZL_CONF" 2>/dev/null || echo 0)
    _pass "plugins.conf: $plugin_lines plugin(s) enabled"
  else
    _warn "plugins.conf: not found (defaults will be used)"
  fi

  # bin/zl
  _check_exec "bin/zl" "$ZL_HOME/bin/zl" || true

  # Symlink in PATH
  if command -v zl &>/dev/null; then
    _pass "zl in PATH: $(command -v zl)"
  else
    _warn "'zl' not found in PATH"
    _hint "Add to PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi

  # doctor.sh
  _check_exec "doctor.sh" "$ZL_HOME/doctor.sh" || true

  # .zshrc injection
  local zshrc="${ZDOTDIR:-$HOME}/.zshrc"
  if [[ -f "$zshrc" ]]; then
    if grep -qF "ZEROLINUX START" "$zshrc" 2>/dev/null; then
      _pass ".zshrc: ZeroLinux block present"
    else
      _fail ".zshrc: ZeroLinux block MISSING"
      _hint "Re-run install.sh or manually add: source \$ZL_HOME/core/loader.zsh"
    fi
    if grep -qF "source.*loader.zsh" "$zshrc" 2>/dev/null; then
      _pass ".zshrc: loader.zsh sourced"
    fi
  else
    _fail ".zshrc: not found at $zshrc"
  fi

  # Log directory
  if [[ -d "$ZL_HOME/logs" ]]; then
    _pass "Log directory: $ZL_HOME/logs"
    if [[ -f "$ZL_HOME/logs/zl.log" ]]; then
      local log_size
      log_size=$(wc -l < "$ZL_HOME/logs/zl.log" 2>/dev/null || echo 0)
      _info "Log file: $log_size lines"
    fi
  else
    _warn "Log directory missing: $ZL_HOME/logs"
    _hint "Fix: mkdir -p $ZL_HOME/logs"
  fi
}

# ── 3. Plugins ────────────────────────────────────────────────────────────────
check_plugins() {
  _section "Plugins"

  local -a enabled=()
  while IFS= read -r p; do
    [[ -n "$p" ]] && enabled+=("$p")
  done < <(_conf_enabled_plugins)

  if (( ${#enabled[@]} == 0 )); then
    _warn "No plugins enabled in plugins.conf"
    return 0
  fi

  _info "Enabled plugins: ${enabled[*]}"
  printf "\n"

  # Track dependency names across all plugins for cross-check
  local -A all_known_plugins=()
  for dir in "$ZL_PLUGINS_DIR"/*/; do
    [[ -d "$dir" ]] && all_known_plugins["$(basename "$dir")"]=1
  done

  local p
  for p in "${enabled[@]}"; do
    local plugin_dir="$ZL_PLUGINS_DIR/$p"

    printf "  ${C_WHITE}${C_BOLD}[Plugin: %s]${C_RESET}\n" "$p"

    # Name validation
    if [[ "$p" =~ ^[a-zA-Z0-9_-]+$ ]]; then
      _pass "  Name valid: $p"
    else
      _fail "  Name invalid: '$p' — only [a-zA-Z0-9_-] allowed"
    fi

    # Directory
    if [[ -d "$plugin_dir" ]]; then
      _pass "  Directory: $plugin_dir"
    else
      _fail "  Directory MISSING: $plugin_dir"
      _hint "Fix: create $plugin_dir or run: zl disable plugin $p"
      continue
    fi

    # init.zsh (required)
    if [[ -f "$plugin_dir/init.zsh" ]]; then
      _pass "  init.zsh: present"
      # Check file is readable and non-empty
      if [[ ! -r "$plugin_dir/init.zsh" ]]; then
        _fail "  init.zsh: not readable"
        _hint "Fix: chmod a+r $plugin_dir/init.zsh"
      elif [[ ! -s "$plugin_dir/init.zsh" ]]; then
        _warn "  init.zsh: empty file"
      fi
    else
      _fail "  init.zsh: MISSING (plugin contract violation)"
      _hint "Every plugin MUST have init.zsh"
    fi

    # commands.zsh (optional)
    if [[ -f "$plugin_dir/commands.zsh" ]]; then
      _pass "  commands.zsh: present"
    else
      _info "  commands.zsh: absent (optional)"
    fi

    # plugin.zl metadata
    if [[ -f "$plugin_dir/plugin.zl" ]]; then
      _pass "  plugin.zl: present"

      local meta_name meta_ver meta_deps meta_req
      meta_name="$(_plugin_meta "$p" "name")"
      meta_ver="$(_plugin_meta "$p" "version")"
      meta_deps="$(_plugin_meta "$p" "dependencies")"
      meta_req="$(_plugin_meta "$p" "requires_zl")"

      [[ -n "$meta_name" ]]  && _info "  name=$meta_name  version=${meta_ver:-?}  requires_zl=${meta_req:-any}"
      [[ -n "$meta_deps"  ]] && _info "  dependencies: $meta_deps"

      # Validate version field (must be semver-like)
      if [[ -n "$meta_ver" && "$meta_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        _pass "  version format valid: $meta_ver"
      elif [[ -n "$meta_ver" ]]; then
        _warn "  version '$meta_ver' not semver (x.y.z expected)"
      else
        _warn "  version field missing in plugin.zl"
      fi

      # Dependency validation
      if [[ -n "$meta_deps" ]]; then
        local dep
        for dep in ${meta_deps//,/ }; do
          dep="${dep// /}"
          [[ -z "$dep" ]] && continue
          if [[ -n "${all_known_plugins[$dep]+_}" ]]; then
            _pass "  dependency '$dep': found"
          else
            _fail "  dependency '$dep': NOT FOUND"
            _hint "Install plugin '$dep' first: zl install plugin $dep"
          fi
        done
      fi

      # Framework version compatibility
      if [[ -n "$meta_req" ]]; then
        local zl_ver
        zl_ver=$(cat "$ZL_HOME/VERSION" 2>/dev/null || echo "2.0.0")
        # Simple version check: major.minor
        local req_major req_minor cur_major cur_minor
        req_major="${meta_req%%.*}"
        req_minor="${meta_req#*.}"; req_minor="${req_minor%%.*}"
        cur_major="${zl_ver%%.*}"
        cur_minor="${zl_ver#*.}"; cur_minor="${cur_minor%%.*}"
        if (( cur_major > req_major || (cur_major == req_major && cur_minor >= req_minor) )); then
          _pass "  ZL compatibility: requires v${meta_req}, current v${zl_ver}"
        else
          _fail "  ZL compatibility: requires v${meta_req}, current v${zl_ver} (too old)"
        fi
      fi
    else
      _warn "  plugin.zl: MISSING (add metadata file)"
    fi

    # Safety check: dangerous patterns (alias overrides, fn redefs, RCE, eval)
    local dangerous_found=0
    local src_file src_fname
    for src_file in "$plugin_dir"/*.zsh; do
      [[ -f "$src_file" ]] || continue
      src_fname="$(basename "$src_file")"
      local _det=0
      grep -Eq 'alias[[:space:]]+(rm|kill|sudo|chmod|chown|mv|cp|cd|ls)[[:space:]]*=' \
        "$src_file" 2>/dev/null && (( _det++ )) && \
        _warn "  Safety: $src_fname overrides a critical command alias"
      grep -Eq 'function[[:space:]]+(rm|kill|sudo|chmod|chown|cd)[[:space:]]*([\(\{]|$)' \
        "$src_file" 2>/dev/null && (( _det++ )) && \
        _warn "  Safety: $src_fname redefines a critical system function"
      grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(sh|bash|zsh)' \
        "$src_file" 2>/dev/null && (( _det++ )) && \
        _warn "  Safety: $src_fname pipes remote content to shell"
      grep -Eq 'eval[[:space:]]+["'"'"']?\$' \
        "$src_file" 2>/dev/null && (( _det++ )) && \
        _warn "  Safety: $src_fname uses eval with variable input"
      (( _det > 0 )) && dangerous_found=$(( dangerous_found + 1 ))
    done
    (( dangerous_found == 0 )) && _pass "  Safety: no dangerous patterns detected"

    # Permissions check
    local perm_issues=0
    for src_file in "$plugin_dir"/*.zsh; do
      [[ -f "$src_file" ]] || continue
      if [[ ! -r "$src_file" ]]; then
        _fail "  Permissions: $(basename "$src_file") not readable"
        perm_issues=$(( perm_issues + 1 ))
      fi
    done
    (( perm_issues == 0 )) && _pass "  Permissions: all .zsh files readable"

    printf "\n"
  done

  # Circular dependency detection (static analysis)
  check_circular_deps "${enabled[@]}"
}

# ── Circular dependency detection (static) ────────────────────────────────────
check_circular_deps() {
  local -a plugins=("$@")
  local -A color=()
  local -A dep_map=()
  local cycle_found=0

  # Build dep map
  local p deps dep
  for p in "${plugins[@]}"; do
    deps="$(_plugin_meta "$p" "dependencies")"
    dep_map[$p]="$deps"
  done

  # DFS
  _dfs_visit() {
    local node="$1"
    local c="${color[$node]:-0}"
    [[ "$c" == "2" ]] && return 0
    if [[ "$c" == "1" ]]; then
      _fail "  Circular dependency detected at: $node"
      cycle_found=$(( cycle_found + 1 ))
      return 1
    fi
    color[$node]=1
    local d
    for d in ${dep_map[$node]//,/ }; do
      d="${d// /}"
      [[ -z "$d" ]] && continue
      dep_map[$d]="${dep_map[$d]:-}"
      _dfs_visit "$d" || return 1
    done
    color[$node]=2
    return 0
  }

  for p in "${plugins[@]}"; do
    _dfs_visit "$p" 2>/dev/null || true
  done

  if (( cycle_found > 0 )); then
    _fail "Circular dependencies found: $cycle_found"
  else
    _pass "Dependency graph: no circular dependencies"
  fi
}

# ── 4. Required tools ──────────────────────────────────────────────────────────
check_tools() {
  _section "Dependencies"

  # Required
  printf "  ${C_BOLD}Required:${C_RESET}\n"
  local -a required=(zsh git curl)
  local tool
  for tool in "${required[@]}"; do
    if command -v "$tool" &>/dev/null; then
      _pass "$tool  →  $(command -v "$tool")"
    else
      _fail "$tool  NOT FOUND"
      _hint "Install: sudo pacman -S $tool  OR  sudo apt-get install $tool"
    fi
  done

  printf "\n  ${C_BOLD}Recommended:${C_RESET}\n"
  local -a recommended=(fzf bat fd rg eza)
  for tool in "${recommended[@]}"; do
    if command -v "$tool" &>/dev/null; then
      _pass "$tool  →  $(command -v "$tool")"
    else
      _warn "$tool  not found (recommended for best experience)"
    fi
  done

  printf "\n  ${C_BOLD}Optional:${C_RESET}\n"
  local -a optional=(lazygit delta zoxide btop nvim tmux thefuck docker)
  for tool in "${optional[@]}"; do
    if command -v "$tool" &>/dev/null; then
      _pass "$tool  →  $(command -v "$tool")"
    else
      _info "$tool  not installed (optional)"
    fi
  done
}

# ── 5. Config validation ──────────────────────────────────────────────────────
check_config() {
  _section "Configuration"

  # plugins.conf integrity
  if [[ -f "$ZL_CONF" ]]; then
    _pass "plugins.conf: exists"
    local line_num=0
    local issues_in_conf=0
    while IFS= read -r line || [[ -n "$line" ]]; do
      line_num=$(( line_num + 1 ))
      local trimmed="${line#"${line%%[![:space:]]*}"}"
      trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
      [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue
      if [[ ! "$trimmed" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        _fail "plugins.conf line $line_num: invalid name '$trimmed'"
        issues_in_conf=$(( issues_in_conf + 1 ))
      fi
    done < "$ZL_CONF"
    (( issues_in_conf == 0 )) && _pass "plugins.conf: all entries valid"
  else
    _warn "plugins.conf: not found (defaults will be used)"
  fi

  # User config
  local user_cfg="${ZDOTDIR:-$HOME}/.zerolinuxrc"
  if [[ -f "$user_cfg" ]]; then
    _pass "$HOME/.zerolinuxrc: present"
    if [[ -r "$user_cfg" ]]; then
      _pass "$HOME/.zerolinuxrc: readable"
    else
      _fail "~/.zerolinuxrc: not readable"
      _hint "Fix: chmod 600 $user_cfg"
    fi
  else
    _info "~/.zerolinuxrc: not found (optional — create to override defaults)"
  fi

  # Default config
  local default_cfg="$ZL_HOME/config/default.zsh"
  if [[ -f "$default_cfg" ]]; then
    _pass "config/default.zsh: present"
  else
    _warn "config/default.zsh: missing"
  fi

  # Cache dir
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zerolinux"
  if [[ -d "$cache_dir" ]]; then
    _pass "Cache dir: $cache_dir"
    if [[ -w "$cache_dir" ]]; then
      _pass "Cache dir: writable"
    else
      _fail "Cache dir: NOT writable"
      _hint "Fix: chmod 755 $cache_dir"
    fi
  else
    _warn "Cache dir not created yet: $cache_dir"
    _hint "It will be created on first shell start"
  fi
}

# ── 6. Fonts ──────────────────────────────────────────────────────────────────
check_fonts() {
  _section "Fonts"

  if ! command -v fc-list &>/dev/null; then
    _warn "fc-list not found — cannot check fonts (fontconfig not installed)"
    return 0
  fi

  if fc-list 2>/dev/null | grep -qi "JetBrainsMono Nerd"; then
    _pass "JetBrainsMono Nerd Font: installed"
  else
    _warn "JetBrainsMono Nerd Font: not found"
    _hint "Icons and glyphs may not render correctly"
    _hint "Download from: https://www.nerdfonts.com/font-downloads"
  fi

  if fc-list 2>/dev/null | grep -qi "Nerd Font"; then
    _pass "At least one Nerd Font detected"
  else
    _warn "No Nerd Fonts found — install one for full icon support"
  fi
}

# ── 7. Shell environment ──────────────────────────────────────────────────────
check_shell_env() {
  _section "Shell Environment"

  # Login shell from /etc/passwd — reliable after chsh, unlike $SHELL env var
  local current_shell
  current_shell="$(getent passwd "${USER:-$(id -un)}" 2>/dev/null | cut -d: -f7 || echo 'unknown')"
  if [[ "$current_shell" == *zsh* ]]; then
    _pass "Default shell: $current_shell"
  else
    _warn "Default shell is not zsh: $current_shell"
    _hint "Fix: chsh -s $(command -v zsh 2>/dev/null || echo /bin/zsh)"
  fi

  # ZL_HOME set
  if [[ -n "${ZL_HOME:-}" ]]; then
    _pass "ZL_HOME=$ZL_HOME"
  else
    _fail "ZL_HOME is not set"
    _hint "This means ZeroLinux has not been sourced in this session"
  fi

  # ZL_LOADER_LOADED (only meaningful if running inside ZL shell)
  if [[ -n "${ZL_LOADER_LOADED:-}" ]]; then
    _pass "ZeroLinux loader: active in this session"
  else
    _info "ZeroLinux loader: not active (running doctor.sh directly)"
  fi

  # PATH includes ZL bin
  if [[ ":${PATH}:" == *":${ZL_HOME}/bin:"* ]] || \
     [[ ":${PATH}:" == *":$HOME/.local/bin:"* ]]; then
    _pass "PATH: includes ZeroLinux bin directory"
  else
    _warn "PATH: ZeroLinux bin not in PATH"
    _hint "Add to .zshrc: export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi

  # Safe mode
  if [[ "${ZL_SAFE_MODE:-0}" == "1" ]]; then
    _warn "ZL_SAFE_MODE=1 is active — plugins are disabled"
    _hint "Unset ZL_SAFE_MODE to re-enable plugins"
  fi

  # Systemd failed services
  if command -v systemctl &>/dev/null; then
    local failed_count
    failed_count=$(systemctl --failed --no-legend 2>/dev/null | wc -l | tr -d ' ')
    if (( failed_count > 0 )); then
      _warn "Systemd: ${failed_count} failed service(s)"
      _hint "Check: systemctl --failed"
    else
      _pass "Systemd: no failed services"
    fi
  fi

  # Network
  if ping -c1 -W2 8.8.8.8 &>/dev/null 2>&1; then
    _pass "Internet: reachable"
  else
    _warn "Internet: not reachable (some features require network)"
  fi
}

# ── 8. Arch-specific ─────────────────────────────────────────────────────────
check_arch() {
  [[ -f /etc/arch-release ]] || return 0
  _section "Arch Linux"

  # Orphaned packages
  if command -v pacman &>/dev/null; then
    local orphans
    orphans=$(pacman -Qtdq 2>/dev/null | wc -l | tr -d ' ')
    if (( orphans > 0 )); then
      _warn "Orphaned packages: $orphans"
      _hint "Clean: sudo pacman -Rns \$(pacman -Qtdq)"
    else
      _pass "No orphaned packages"
    fi

    # Available updates
    if command -v checkupdates &>/dev/null; then
      local updates
      updates=$(checkupdates 2>/dev/null | wc -l | tr -d ' ' || echo 0)
      if (( updates > 0 )); then
        _warn "Updates available: $updates package(s)"
        _hint "Update: sudo pacman -Syu"
      else
        _pass "System up to date"
      fi
    fi

    # AUR helper
    local aur_helper=""
    local h
    for h in yay paru pikaur; do
      command -v "$h" &>/dev/null && aur_helper="$h" && break
    done
    if [[ -n "$aur_helper" ]]; then
      _pass "AUR helper: $aur_helper"
    else
      _info "AUR helper: none found (yay/paru recommended)"
    fi
  fi
}

# =============================================================================
# SUMMARY
# =============================================================================
print_summary() {
  printf "\n${C_BLUE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"
  printf "  ${C_BOLD}Doctor Summary${C_RESET}\n"
  printf "  ${C_GREEN}PASS:${C_RESET} %-4s  ${C_YELLOW}WARN:${C_RESET} %-4s  ${C_RED}FAIL:${C_RESET} %-4s  Total: %s\n" \
    "$pass_count" "$warn_count" "$fail_count" "$total_checks"
  printf "${C_BLUE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n"

  if (( fail_count == 0 && warn_count == 0 )); then
    printf "  ${C_GREEN}${C_BOLD}✅  All checks passed — system is healthy${C_RESET}\n"
  elif (( fail_count == 0 )); then
    printf "  ${C_YELLOW}${C_BOLD}⚠   %d warning(s) — review above${C_RESET}\n" "$warn_count"
  else
    printf "  ${C_RED}${C_BOLD}✗   %d failure(s), %d warning(s) — action required${C_RESET}\n" \
      "$fail_count" "$warn_count"
    printf "  ${C_DIM}  Run: zl help  for remediation commands${C_RESET}\n"
  fi
  printf "${C_BLUE}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}\n\n"
}

# =============================================================================
# MAIN
# =============================================================================
main() {
  printf "\n${C_BLUE}${C_BOLD}  ZeroLinux Terminal — Doctor v%s${C_RESET}\n" \
    "$(cat "$ZL_HOME/VERSION" 2>/dev/null || echo "2.0.0")"
  printf "  ${C_DIM}%s${C_RESET}\n\n" "$(date '+%Y-%m-%d %H:%M:%S')"

  check_system
  check_installation
  check_plugins
  check_tools
  check_config
  check_fonts
  check_shell_env
  check_arch

  print_summary

  # Exit code: 0=healthy, 1=failures, 2=warnings only
  if   (( fail_count > 0 )); then return 1
  elif (( warn_count > 0 )); then return 2
  else return 0
  fi
}

main "$@"
