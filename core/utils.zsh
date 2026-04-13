# =============================================================================
# ZeroLinux Terminal Framework v2 — core/utils.zsh
# Shared utility functions. Namespace: zl::*
#
# Contract:
#   - All public functions use zl:: namespace
#   - No global variable pollution (use typeset -g when global state needed)
#   - Never crash — every function returns meaningful exit codes
#   - Backward compat wrappers for v1 API (zl_has, zl_file_ok, etc.)
# =============================================================================

[[ -n "${ZL_UTILS_LOADED:-}" ]] && return 0
typeset -g ZL_UTILS_LOADED=1

# ── Command availability ───────────────────────────────────────────────────────
zl::has() {
  [[ -n "${1:-}" ]] && command -v "$1" &>/dev/null
}

# ── File / dir guards ─────────────────────────────────────────────────────────
zl::file::exists() {
  [[ -n "${1:-}" && -f "$1" ]]
}

zl::file::readable() {
  [[ -n "${1:-}" && -f "$1" && -r "$1" ]]
}

zl::file::nonempty() {
  [[ -n "${1:-}" && -f "$1" && -s "$1" ]]
}

zl::dir::exists() {
  [[ -n "${1:-}" && -d "$1" ]]
}

zl::dir::ensure() {
  local dir="${1:-}"
  [[ -z "$dir" ]] && return 1
  [[ -d "$dir" ]] && return 0
  mkdir -p "$dir" 2>/dev/null || {
    zl::log::error "Cannot create directory: $dir"
    return 1
  }
}

# ── Safe source ───────────────────────────────────────────────────────────────
# Sources a file safely. On failure: logs, returns 1. Never kills shell.
zl::source() {
  local file="${1:-}"
  if [[ -z "$file" ]]; then
    zl::log::error "zl::source called with empty path"
    return 1
  fi
  if [[ ! -f "$file" ]]; then
    zl::log::error "File not found: $file"
    return 1
  fi
  if [[ ! -r "$file" ]]; then
    zl::log::error "Permission denied: $file"
    return 1
  fi
  source "$file" || {
    zl::log::error "Failed to source: $file"
    return 1
  }
  return 0
}

# ── Safe execution ────────────────────────────────────────────────────────────
zl::exec() {
  "$@" || {
    zl::log::error "Command failed (exit $?): $*"
    return 1
  }
}

# ── Identity helpers ──────────────────────────────────────────────────────────
zl::is_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]]
}

zl::is_interactive() {
  [[ $- == *i* ]]
}

# ── Distro detection ──────────────────────────────────────────────────────────
zl::distro() {
  if [[ -f /etc/arch-release ]]; then
    echo "arch"
  elif [[ -f /etc/debian_version ]]; then
    grep -qi ubuntu /etc/os-release 2>/dev/null && echo "ubuntu" || echo "debian"
  elif [[ -f /etc/fedora-release ]]; then
    echo "fedora"
  elif [[ -f /etc/os-release ]]; then
    local _id
    _id=$(grep '^ID=' /etc/os-release | cut -d= -f2 | tr -d '"')
    echo "${_id:-unknown}"
  else
    echo "unknown"
  fi
}

# ── AUR helper ────────────────────────────────────────────────────────────────
zl::aur_helper() {
  local h
  for h in yay paru pikaur; do
    zl::has "$h" && echo "$h" && return 0
  done
  return 1
}

# ── String helpers ────────────────────────────────────────────────────────────
zl::str::trim() {
  local s="$*"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  echo "$s"
}

zl::str::is_valid_name() {
  # Plugin / theme name: alphanumeric + dash + underscore only
  [[ "${1:-}" =~ ^[a-zA-Z0-9_-]+$ ]]
}

# ── Version comparison ────────────────────────────────────────────────────────
# Returns 0 if $1 >= $2  (semver: major.minor.patch)
# Fix v2.1.1: previous version used (( )) arithmetic directly on split strings
# which produced "bad floating point constant" when strings had trailing chars
# (e.g. "1.0.0-beta"). Now uses explicit base-10 integer coercion via printf %d.
zl::version::gte() {
  local a="${1:-0.0.0}" b="${2:-0.0.0}"
  local -a va vb
  # Split on '.' without altering global IFS
  # shellcheck disable=SC2296
  IFS='.' read -rA va <<< "$a" 2>/dev/null || { IFS='.' read -ra va <<< "$a"; }
  # shellcheck disable=SC2296
  IFS='.' read -rA vb <<< "$b" 2>/dev/null || { IFS='.' read -ra vb <<< "$b"; }
  local i ai bi va_i vb_i
  for i in 1 2 3; do
    # Strip any non-numeric suffix (e.g. "1-beta" → 1); default to 0
    va_i="${va[$i]:-0}"; va_i="${va_i%%[^0-9]*}"
    vb_i="${vb[$i]:-0}"; vb_i="${vb_i%%[^0-9]*}"
    ai=$(( va_i + 0 ))
    bi=$(( vb_i + 0 ))
    (( ai > bi )) && return 0
    (( ai < bi )) && return 1
  done
  return 0  # equal
}

# ── Log rotation ──────────────────────────────────────────────────────────────
zl::log::rotate() {
  local max_lines="${1:-5000}"
  local log_file="${ZL_LOG:-}"
  [[ -z "$log_file" || ! -f "$log_file" ]] && return 0
  local lines
  lines=$(wc -l < "$log_file" 2>/dev/null || echo 0)
  if (( lines > max_lines )); then
    tail -1000 "$log_file" > "${log_file}.tmp" 2>/dev/null \
      && mv "${log_file}.tmp" "$log_file" 2>/dev/null \
      || true
    zl::log::info "Log rotated (${lines} → 1000 lines)"
  fi
}

# ── Backward compat (v1 API) ──────────────────────────────────────────────────
zl_has()     { zl::has     "$@"; }
zl_file_ok() { zl::file::nonempty "$@"; }
zl_dir_ok()  { zl::dir::exists    "$@"; }
zl_is_root() { zl::is_root; }
safe_exec()  { zl::exec    "$@"; }

# ── Telemetry (ZL_TELEMETRY=1, off by default, NO network calls) ──────────────
# Records startup and plugin load times to log file only.
typeset -gA ZL_TELEMETRY_DATA=()

zl::telemetry::record() {
  [[ "${ZL_TELEMETRY:-0}" != "1" ]] && return 0
  local key="$1" value="$2"
  ZL_TELEMETRY_DATA["$key"]="$value"
  zl::log::debug "telemetry[$key]=${value}"
}

zl::telemetry::report() {
  [[ "${ZL_TELEMETRY:-0}" != "1" ]] && return 0
  local k
  zl::log::debug "=== Telemetry Report ==="
  # shellcheck disable=SC2296
  for k in "${(k)ZL_TELEMETRY_DATA[@]}"; do
    zl::log::debug "  ${k}: ${ZL_TELEMETRY_DATA[$k]}"
  done
}
