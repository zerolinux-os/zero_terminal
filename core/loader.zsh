# =============================================================================
# ZeroLinux Terminal Framework v2 — core/loader.zsh
# Shell entrypoint. Source this from ~/.zshrc.
#
# SAFETY CONTRACT:
#   - NEVER crashes the shell under ANY condition
#   - Every source() call is guarded
#   - Plugin failures are fully isolated
#   - ZL_SAFE_MODE=1 disables plugins, loads core only
#   - Duplicate sourcing prevented by ZL_LOADER_LOADED guard
#   - Startup time is tracked and logged at DEBUG level
# =============================================================================

[[ -n "${ZL_LOADER_LOADED:-}" ]] && return 0
typeset -gx ZL_LOADER_LOADED=1

# ── Shell identity — exported so child processes (bin/zl) can detect the parent
typeset -gx ZL_SHELL="${ZSH_NAME:-${SHELL##*/}}"

# ── Version ───────────────────────────────────────────────────────────────────
typeset -gx ZL_VERSION="$(cat "$ZL_HOME/VERSION" 2>/dev/null || echo "2.1.1")"

# ── Root dirs ─────────────────────────────────────────────────────────────────
typeset -gx ZL_HOME="${ZL_HOME:-$HOME/.zerolinux}"
typeset -gx ZL_PLUGINS_DIR="$ZL_HOME/plugins"
typeset -gx ZL_THEMES_DIR="$ZL_HOME/themes"
typeset -gx ZL_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zerolinux"
typeset -gx ZL_LOG="$ZL_HOME/logs/zl.log"

# ── Bootstrap dirs ────────────────────────────────────────────────────────────
[[ -d "$ZL_CACHE_DIR"    ]] || mkdir -p "$ZL_CACHE_DIR"    2>/dev/null || true
[[ -d "$ZL_HOME/logs"    ]] || mkdir -p "$ZL_HOME/logs"    2>/dev/null || true
[[ -d "$ZL_HOME/core"    ]] || mkdir -p "$ZL_HOME/core"    2>/dev/null || true
[[ -d "$ZL_PLUGINS_DIR"  ]] || mkdir -p "$ZL_PLUGINS_DIR"  2>/dev/null || true

# ── Bootstrap logger (minimal, before logger.zsh loads) ──────────────────────
_zl_boot_warn()  {
  echo -e "\033[1;33m[ZL:BOOT:WARN]\033[0m  $*" >&2
  printf '[%s] [WARN]  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" \
    >> "$ZL_LOG" 2>/dev/null || true
}
_zl_boot_error() {
  echo -e "\033[1;31m[ZL:BOOT:ERROR]\033[0m $*" >&2
  printf '[%s] [ERROR] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" \
    >> "$ZL_LOG" 2>/dev/null || true
}

# ── Core source helper ────────────────────────────────────────────────────────
_zl_source_core() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    _zl_boot_error "Core file missing: $file"
    return 1
  fi
  if [[ ! -r "$file" ]]; then
    _zl_boot_error "Core file not readable: $file"
    return 1
  fi
  source "$file" || {
    _zl_boot_error "Core file failed to source: $file"
    return 1
  }
}

# ── Load: 1. logger (must be first for structured output) ─────────────────────
_zl_source_core "$ZL_HOME/core/logger.zsh" || \
  _zl_boot_warn "logger.zsh failed — output will be unstructured"

# ── Load: 2. utils ────────────────────────────────────────────────────────────
_zl_source_core "$ZL_HOME/core/utils.zsh" || \
  _zl_boot_warn "utils.zsh failed — helper functions unavailable"

# ── Load: 3. plugin manager ───────────────────────────────────────────────────
_zl_source_core "$ZL_HOME/core/plugin_manager.zsh" || \
  _zl_boot_warn "plugin_manager.zsh failed — plugins will not load"

# ── Load: 4. config (shell env, aliases, completions) ─────────────────────────
_zl_source_core "$ZL_HOME/core/config.zsh" || \
  _zl_boot_warn "config.zsh failed — shell environment may be unconfigured"

# ── Autocorrect ───────────────────────────────────────────────────────────────
# Zsh's spell-correction (CORRECT / CORRECT_ALL) rewrites subcommands like
# "zl disable", "zl remove", and "git reset" into wrong commands.
# ZL_DISABLE_AUTOCORRECT=1 (default) silently suppresses it.
# Set ZL_DISABLE_AUTOCORRECT=0 in ~/.zerolinuxrc to keep zsh correction.
if [[ "${ZL_DISABLE_AUTOCORRECT:-1}" -eq 1 ]]; then
  unsetopt correct correctall 2>/dev/null || true
  zl::log::debug "Autocorrect disabled (ZL_DISABLE_AUTOCORRECT=1)"
fi

# ── Welcome ───────────────────────────────────────────────────────────────────
_zl_welcome() {
  [[ $- != *i* ]]                                        && return 0
  [[ -n "${TMUX:-}" ]]                                   && return 0
  [[ "${TERM_PROGRAM:-}" == "vscode" ]]                  && return 0
  [[ "${TERMINAL_EMULATOR:-}" == "JetBrains-JediTerm" ]] && return 0
  [[ -n "${ZL_WELCOMED:-}" ]]                            && return 0
  typeset -gx ZL_WELCOMED=1
  local welcome="$ZL_HOME/core/welcome.zsh"
  [[ -f "$welcome" ]] && source "$welcome" 2>/dev/null || true
}
_zl_welcome

# ── Safe mode guard ───────────────────────────────────────────────────────────
if [[ "${ZL_SAFE_MODE:-0}" == "1" ]]; then
  zl::log::warn "ZL_SAFE_MODE=1 active — all plugins disabled"
  zl::log::warn "Unset ZL_SAFE_MODE and restart shell to re-enable plugins"
  return 0
fi

# ── Load plugins ──────────────────────────────────────────────────────────────
typeset -F 6 _zl_t0 _zl_t1
_zl_t0=$EPOCHREALTIME

if typeset -f "zl::plugin::load_all" &>/dev/null; then
  zl::plugin::load_all
else
  _zl_boot_warn "plugin_manager not available — plugins skipped"
fi

_zl_t1=$EPOCHREALTIME
if (( _zl_t0 > 0 )); then
  integer _zl_elapsed=$(( (_zl_t1 - _zl_t0) * 1000 + 0.5 ))
  zl::log::debug "Total load time: ${_zl_elapsed}ms"
  (( _zl_elapsed > 200 )) && \
    zl::log::warn "Slow startup (${_zl_elapsed}ms) — try disabling unused plugins"
fi
unset _zl_t0 _zl_t1 _zl_elapsed

# ── Cleanup bootstrap helpers ─────────────────────────────────────────────────
unfunction _zl_source_core _zl_welcome _zl_boot_warn _zl_boot_error 2>/dev/null || true
