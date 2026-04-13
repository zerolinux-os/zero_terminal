# =============================================================================
# ZeroLinux Terminal Framework v2 — core/logger.zsh
# Structured logging with levels: DEBUG INFO WARN ERROR
#
# Namespace: zl::log::*
# Contract:
#   - Never crash the shell under any condition
#   - Respects ZL_LOG_LEVEL (DEBUG=0 INFO=1 WARN=2 ERROR=3)
#   - Respects ZL_LOG_SILENT=1 to suppress terminal output
#   - File logging always appends; failures are silenced with || true
# =============================================================================

[[ -n "${ZL_LOGGER_LOADED:-}" ]] && return 0
typeset -g ZL_LOGGER_LOADED=1

# ── Log level constants ────────────────────────────────────────────────────────
typeset -gi ZL_LOG_LEVEL_DEBUG=0
typeset -gi ZL_LOG_LEVEL_INFO=1
typeset -gi ZL_LOG_LEVEL_WARN=2
typeset -gi ZL_LOG_LEVEL_ERROR=3

# Default: INFO. Override via ZL_LOG_LEVEL env var.
typeset -gi ZL_LOG_LEVEL="${ZL_LOG_LEVEL:-1}"

# ── ANSI color codes (no external deps) ───────────────────────────────────────
typeset -gA ZL_C=(
  reset   $'\033[0m'
  bold    $'\033[1m'
  dim     $'\033[2m'
  blue    $'\033[1;34m'
  cyan    $'\033[0;36m'
  green   $'\033[0;32m'
  yellow  $'\033[1;33m'
  red     $'\033[1;31m'
  purple  $'\033[0;35m'
  gray    $'\033[2;37m'
  white   $'\033[1;37m'
)

# ── Internal: write to log file ───────────────────────────────────────────────
_zl::log::write() {
  local level="$1" msg="$2"
  local log_file="${ZL_LOG:-/dev/null}"
  [[ "$log_file" == "/dev/null" ]] && return 0
  # Ensure log dir exists without crashing
  local log_dir="${log_file%/*}"
  [[ -d "$log_dir" ]] || mkdir -p "$log_dir" 2>/dev/null || return 0
  printf '[%s] [%-5s] %s\n' \
    "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$msg" \
    >> "$log_file" 2>/dev/null || true
}

# ── Internal: level check ─────────────────────────────────────────────────────
_zl::log::should_print() {
  local numeric_level="$1"
  (( numeric_level >= ZL_LOG_LEVEL ))
}

# ── Public API ────────────────────────────────────────────────────────────────

zl::log::debug() {
  _zl::log::write "DEBUG" "$*"
  _zl::log::should_print $ZL_LOG_LEVEL_DEBUG || return 0
  [[ "${ZL_LOG_SILENT:-0}" == "1" ]] && return 0
  echo -e "${ZL_C[gray]}${ZL_C[bold]}[ZL:DEBUG]${ZL_C[reset]}${ZL_C[gray]} $*${ZL_C[reset]}"
}

zl::log::info() {
  _zl::log::write "INFO" "$*"
  _zl::log::should_print $ZL_LOG_LEVEL_INFO || return 0
  [[ "${ZL_LOG_SILENT:-0}" == "1" ]] && return 0
  echo -e "${ZL_C[cyan]}[ZL:INFO]${ZL_C[reset]}  $*"
}

zl::log::warn() {
  _zl::log::write "WARN" "$*"
  _zl::log::should_print $ZL_LOG_LEVEL_WARN || return 0
  echo -e "${ZL_C[yellow]}[ZL:WARN]${ZL_C[reset]}  $*" >&2
}

zl::log::error() {
  _zl::log::write "ERROR" "$*"
  _zl::log::should_print $ZL_LOG_LEVEL_ERROR || return 0
  echo -e "${ZL_C[red]}${ZL_C[bold]}[ZL:ERROR]${ZL_C[reset]} $*" >&2
}

# Convenience: step header (always printed unless ZL_LOG_SILENT)
zl::log::step() {
  [[ "${ZL_LOG_SILENT:-0}" == "1" ]] && return 0
  echo -e "\n${ZL_C[blue]}${ZL_C[bold]}━━━ $* ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${ZL_C[reset]}"
}

zl::log::ok() {
  [[ "${ZL_LOG_SILENT:-0}" == "1" ]] && return 0
  echo -e "${ZL_C[green]}  ✓${ZL_C[reset]}  $*"
  _zl::log::write "INFO" "OK: $*"
}

# Backward compat aliases (v1 callers: log_info, log_warn, log_error)
log_info()  { zl::log::info  "$@"; }
log_warn()  { zl::log::warn  "$@"; }
log_error() { zl::log::error "$@"; }
log_ok()    { zl::log::ok    "$@"; }
zl_info()   { zl::log::info  "$@"; }
zl_warn()   { zl::log::warn  "$@"; }
zl_err()    { zl::log::error "$@"; }
zl_ok()     { zl::log::ok    "$@"; }
