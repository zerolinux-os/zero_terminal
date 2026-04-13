# =============================================================================
# ZeroLinux Terminal Framework v2 — core/plugin_manager.zsh
# Plugin lifecycle: validation, dependency resolution, loading.
#
# Namespace: zl::plugin::*
#
# Plugin Contract (EVERY plugin MUST follow):
#   <plugin_dir>/
#     plugin.zl      — metadata: name, version, description, dependencies
#     init.zsh       — must define plugin_init()
#     commands.zsh   — must define plugin_register_commands() [optional]
#
# Contract guarantees:
#   - Circular dependency detection (topological sort, DFS)
#   - Broken plugin cannot crash the shell
#   - Duplicate load prevention per session
#   - Safety scanner for dangerous patterns
#   - All functions namespaced zl::plugin::*
#
# FIX-07: Removed install_lazy_stub() — it used eval and was never wired into
#         load_all(). True lazy loading in zsh requires zle hooks which depend
#         on the plugin's own command names; the right approach is fast eager
#         loading with compinit -C caching, not synthetic stubs.
# =============================================================================

[[ -n "${ZL_PLUGIN_MANAGER_LOADED:-}" ]] && return 0
typeset -g ZL_PLUGIN_MANAGER_LOADED=1

# ── Core dependency bootstrap ─────────────────────────────────────────────────
# plugin_manager.zsh relies on zl::log::* (logger.zsh) and zl::has / zl::str::*
# (utils.zsh). Under normal startup loader.zsh sources them first.
# This guard handles every other case — manual sourcing, re-exec, test harnesses —
# by re-sourcing the files if the functions are not yet defined.
# Both files are idempotent (ZL_LOGGER_LOADED / ZL_UTILS_LOADED guards inside them),
# so sourcing twice costs nothing and introduces no side effects.
if [[ -z "${ZL_LOGGER_LOADED:-}" ]]; then
  source "${ZL_HOME:-$HOME/.zerolinux}/core/logger.zsh" 2>/dev/null || true
fi
if [[ -z "${ZL_UTILS_LOADED:-}" ]]; then
  source "${ZL_HOME:-$HOME/.zerolinux}/core/utils.zsh" 2>/dev/null || true
fi

# ── State ─────────────────────────────────────────────────────────────────────
typeset -gA ZL_PLUGIN_LOADED=()       # [name]=1 when fully loaded
typeset -gA ZL_PLUGIN_FAILED=()       # [name]=1 when failed
typeset -gA ZL_PLUGIN_META=()         # [name:key]=value from plugin.zl
typeset -ga ZL_PLUGIN_LOAD_ORDER=()   # resolved dependency order
typeset -ga ZL_PLUGINS=()             # names of successfully loaded plugins

# ── Metadata parser ───────────────────────────────────────────────────────────
# Reads plugin.zl (KEY=value format) into ZL_PLUGIN_META[name:key]
zl::plugin::read_meta() {
  local name="$1"
  local meta_file="$ZL_PLUGINS_DIR/$name/plugin.zl"

  if [[ ! -f "$meta_file" ]]; then
    zl::log::debug "plugin[$name]: plugin.zl not found — using defaults"
    ZL_PLUGIN_META["${name}:name"]="$name"
    ZL_PLUGIN_META["${name}:version"]="0.0.0"
    ZL_PLUGIN_META["${name}:description"]="(no metadata)"
    ZL_PLUGIN_META["${name}:dependencies"]=""
    return 0
  fi

  local line key value
  while IFS='=' read -r key value || [[ -n "$key" ]]; do
    key="$(zl::str::trim "$key")"
    value="$(zl::str::trim "$value")"
    [[ -z "$key" || "$key" == \#* ]] && continue
    # Validate key — only [a-zA-Z0-9_] allowed
    [[ "$key" =~ ^[a-zA-Z0-9_]+$ ]] || continue
    ZL_PLUGIN_META["${name}:${key}"]="$value"
  done < "$meta_file"

  # Ensure required fields have defaults
  ZL_PLUGIN_META["${name}:name"]="${ZL_PLUGIN_META["${name}:name"]:-$name}"
  ZL_PLUGIN_META["${name}:version"]="${ZL_PLUGIN_META["${name}:version"]:-0.0.0}"
  ZL_PLUGIN_META["${name}:dependencies"]="${ZL_PLUGIN_META["${name}:dependencies"]:-}"
}

# ── Validate plugin structure ─────────────────────────────────────────────────
# Returns 0 if valid, 1 if broken.
zl::plugin::validate() {
  local name="$1"
  local plugin_dir="$ZL_PLUGINS_DIR/$name"
  local ok=0

  if [[ ! -d "$plugin_dir" ]]; then
    zl::log::error "plugin[$name]: directory not found: $plugin_dir"
    return 1
  fi

  if [[ ! -f "$plugin_dir/init.zsh" ]]; then
    zl::log::error "plugin[$name]: init.zsh missing (REQUIRED by plugin contract)"
    ok=1
  elif [[ ! -r "$plugin_dir/init.zsh" ]]; then
    zl::log::error "plugin[$name]: init.zsh not readable (check permissions)"
    ok=1
  fi

  if [[ ! -f "$plugin_dir/plugin.zl" ]]; then
    zl::log::warn "plugin[$name]: plugin.zl missing (metadata recommended)"
  fi

  # Validate name is safe
  if ! zl::str::is_valid_name "$name"; then
    zl::log::error "plugin[$name]: invalid name — only [a-zA-Z0-9_-] allowed"
    ok=1
  fi

  return $ok
}

# ── Safety scanner ────────────────────────────────────────────────────────────
# Returns 0 if safe, number of issues found if unsafe.
# Does NOT block load — warns and logs. Blocking is opt-in via ZL_STRICT_SAFETY.
zl::plugin::safety_scan() {
  local name="$1"
  local plugin_dir="$ZL_PLUGINS_DIR/$name"
  local issues=0
  local f fname

  for f in "$plugin_dir"/*.zsh; do
    [[ -f "$f" ]] || continue
    fname="$(basename "$f")"
    local detected=0

    grep -Eq 'alias[[:space:]]+(rm|kill|sudo|chmod|chown|mv|cp|cd|ls)[[:space:]]*=' \
      "$f" 2>/dev/null && (( detected++ )) && \
      zl::log::warn "SECURITY: plugin[$name]/$fname overrides a critical command alias"

    grep -Eq 'function[[:space:]]+(rm|kill|sudo|chmod|chown|cd)[[:space:]]*([\(\{]|$)' \
      "$f" 2>/dev/null && (( detected++ )) && \
      zl::log::warn "SECURITY: plugin[$name]/$fname redefines a critical system function"

    grep -Eq '(curl|wget)[^|]*\|[[:space:]]*(sh|bash|zsh)' \
      "$f" 2>/dev/null && (( detected++ )) && \
      zl::log::warn "SECURITY: plugin[$name]/$fname pipes remote content to shell"

    grep -Eq 'eval[[:space:]]+["'"'"']?\$' \
      "$f" 2>/dev/null && (( detected++ )) && \
      zl::log::warn "SECURITY: plugin[$name]/$fname uses eval with variable input"

    (( detected > 0 )) && issues=$(( issues + 1 ))
  done

  if (( issues > 0 )); then
    zl::log::warn "plugin[$name]: security concerns in $issues file(s)"
    # If strict safety mode is enabled, refuse to load
    if [[ "${ZL_STRICT_SAFETY:-0}" == "1" ]]; then
      zl::log::error "plugin[$name]: blocked by ZL_STRICT_SAFETY=1"
      return $issues
    fi
  fi

  return 0
}

# ── Dependency resolver (topological sort) ────────────────────────────────────
# Fills ZL_PLUGIN_LOAD_ORDER with correctly ordered plugin list.
# Detects circular dependencies via DFS with 3-state coloring:
#   0 = unvisited (white), 1 = in-stack (gray), 2 = done (black)
zl::plugin::resolve_deps() {
  local -a requested=("$@")
  local -A _color=()
  local -a _sorted=()
  local _cycle_detected=0

  # Inner DFS — uses outer scope arrays via closure
  _zl_pm_visit() {
    local node="$1"
    local c="${_color[$node]:-0}"

    if [[ "$c" == "1" ]]; then
      zl::log::error "Circular dependency detected involving: $node"
      _cycle_detected=1
      return 1
    fi
    [[ "$c" == "2" ]] && return 0

    _color[$node]=1

    local deps="${ZL_PLUGIN_META["${node}:dependencies"]:-}"
    local dep
    if [[ -n "$deps" ]]; then
      # shellcheck disable=SC2296
      for dep in ${(s:,:)deps}; do
        dep="$(zl::str::trim "$dep")"
        [[ -z "$dep" ]] && continue
        # Load metadata for dependency if not yet known
        if [[ -z "${ZL_PLUGIN_META["${dep}:name"]:-}" ]]; then
          zl::plugin::read_meta "$dep" 2>/dev/null || true
        fi
        _zl_pm_visit "$dep" || return 1
      done
    fi

    _color[$node]=2
    _sorted+=("$node")
  }

  # Load metadata for all requested plugins first
  local p
  for p in "${requested[@]}"; do
    zl::plugin::read_meta "$p"
  done

  for p in "${requested[@]}"; do
    _zl_pm_visit "$p" || {
      if (( _cycle_detected )); then
        zl::log::error "Aborting dependency resolution — circular dependency found"
        unfunction _zl_pm_visit 2>/dev/null || true
        return 1
      fi
    }
  done

  unfunction _zl_pm_visit 2>/dev/null || true
  ZL_PLUGIN_LOAD_ORDER=("${_sorted[@]}")
  return 0
}

# ── Plugin loader ─────────────────────────────────────────────────────────────
zl::plugin::load_now() {
  local name="$1"

  # Skip if already loaded or previously failed
  [[ -n "${ZL_PLUGIN_LOADED[$name]+_}" ]] && return 0
  [[ -n "${ZL_PLUGIN_FAILED[$name]+_}" ]] && return 1

  # ── Core pre-flight ─────────────────────────────────────────────────────────
  # Guarantee zl::log::* and zl::has are available before any plugin code runs.
  # The guard variables make both sources a no-op if already loaded.
  [[ -z "${ZL_LOGGER_LOADED:-}" ]] && \
    source "${ZL_HOME:-$HOME/.zerolinux}/core/logger.zsh"  2>/dev/null || true
  [[ -z "${ZL_UTILS_LOADED:-}"  ]] && \
    source "${ZL_HOME:-$HOME/.zerolinux}/core/utils.zsh"   2>/dev/null || true

  local plugin_dir="$ZL_PLUGINS_DIR/$name"
  local init_file="$plugin_dir/init.zsh"
  local cmd_file="$plugin_dir/commands.zsh"

  # Structural validation
  zl::plugin::validate "$name" || {
    ZL_PLUGIN_FAILED[$name]=1
    return 1
  }

  # Read metadata
  zl::plugin::read_meta "$name"

  # Framework version compatibility check
  local requires_zl="${ZL_PLUGIN_META["${name}:requires_zl"]:-0.0.0}"
  local current_version
  current_version="$(cat "$ZL_HOME/VERSION" 2>/dev/null || echo "2.1.1")"
  if ! zl::version::gte "$current_version" "$requires_zl"; then
    zl::log::error "plugin[$name]: requires ZL v${requires_zl}, installed v${current_version}"
    ZL_PLUGIN_FAILED[$name]=1
    return 1
  fi

  # Safety scan (warns; blocks only if ZL_STRICT_SAFETY=1)
  zl::plugin::safety_scan "$name" || {
    ZL_PLUGIN_FAILED[$name]=1
    return 1
  }

  # Time the load
  typeset -F 6 t_start t_end
  t_start=$EPOCHREALTIME

  # ── Lifecycle step 1: source init.zsh ────────────────────────────────────
  # Errors are isolated — never kill the shell
  {
    source "$init_file" 2>/dev/null
  } || {
    zl::log::error "plugin[$name]: init.zsh failed to source"
    ZL_PLUGIN_FAILED[$name]=1
    return 1
  }

  # ── Lifecycle step 2: call plugin_init() ─────────────────────────────────
  # Defined by init.zsh. Unregistered after call to prevent global pollution.
  if typeset -f "plugin_init" &>/dev/null; then
    plugin_init 2>/dev/null || \
      zl::log::warn "plugin[$name]: plugin_init() returned error (non-fatal)"
    unfunction plugin_init 2>/dev/null || true
  fi

  # ── Lifecycle step 3: source commands.zsh ────────────────────────────────
  # ONLY the plugin_manager sources commands.zsh.
  # Plugins must NOT source it themselves — doing so causes double execution.
  if [[ -f "$cmd_file" && -r "$cmd_file" ]]; then
    source "$cmd_file" 2>/dev/null || \
      zl::log::warn "plugin[$name]: commands.zsh failed (non-fatal)"
  fi

  # ── Lifecycle step 4: call plugin_register_commands() ────────────────────
  # Optional hook defined by commands.zsh. Unregistered after call.
  if typeset -f "plugin_register_commands" &>/dev/null; then
    plugin_register_commands 2>/dev/null || true
    unfunction plugin_register_commands 2>/dev/null || true
  fi

  # ── Timing ─────────────────────────────────────────────────────────────────
  t_end=$EPOCHREALTIME
  if (( t_start > 0 )); then
    local elapsed_ms
    elapsed_ms=$(awk "BEGIN {printf \"%d\", (${t_end} - ${t_start}) * 1000 + 0.5}")
    (( elapsed_ms > 100 )) && \
      zl::log::warn "plugin[$name]: slow load (${elapsed_ms}ms)"
    zl::log::debug "plugin[$name]: loaded in ${elapsed_ms}ms (v${ZL_PLUGIN_META["${name}:version"]:-?})"
  fi

  ZL_PLUGIN_LOADED[$name]=1
  ZL_PLUGINS+=("$name")
  return 0
}

# ── Load all enabled plugins ──────────────────────────────────────────────────
zl::plugin::load_all() {
  local conf_file="$ZL_HOME/core/plugins.conf"
  local -a requested=()

  if [[ -f "$conf_file" ]]; then
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="$(zl::str::trim "$line")"
      [[ -z "$line" || "$line" == \#* ]] && continue
      if ! zl::str::is_valid_name "$line"; then
        zl::log::warn "plugins.conf: invalid entry ignored: '$line'"
        continue
      fi
      requested+=("$line")
    done < "$conf_file"
  else
    zl::log::warn "plugins.conf not found — loading defaults: git system"
    requested=(git system)
  fi

  if (( ${#requested[@]} == 0 )); then
    zl::log::debug "No plugins enabled in plugins.conf"
    return 0
  fi

  # Resolve dependency order
  if ! zl::plugin::resolve_deps "${requested[@]}"; then
    zl::log::error "Dependency resolution failed — loading in declared order"
    ZL_PLUGIN_LOAD_ORDER=("${requested[@]}")
  fi

  zl::log::debug "Plugin load order: ${ZL_PLUGIN_LOAD_ORDER[*]}"

  # Load in resolved order — failures never abort the loop
  local p
  for p in "${ZL_PLUGIN_LOAD_ORDER[@]}"; do
    zl::plugin::load_now "$p" || true
  done
}

# ── Plugin list ───────────────────────────────────────────────────────────────
zl::plugin::list() {
  local conf_file="$ZL_HOME/core/plugins.conf"
  local -a enabled=()

  if [[ -f "$conf_file" ]]; then
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="$(zl::str::trim "$line")"
      [[ -z "$line" || "$line" == \#* ]] && continue
      enabled+=("$line")
    done < "$conf_file"
  fi

  local found=0
  local p
  for dir in "$ZL_PLUGINS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    p="$(basename "$dir")"
    local meta_ver meta_desc status_str

    meta_ver="${ZL_PLUGIN_META["${p}:version"]:-?}"
    meta_desc="${ZL_PLUGIN_META["${p}:description"]:-(no description)}"

    if [[ -n "${ZL_PLUGIN_LOADED[$p]+_}" ]]; then
      status_str="${ZL_C[green]:-\033[0;32m}● loaded${ZL_C[reset]:-\033[0m}"
    elif [[ -n "${ZL_PLUGIN_FAILED[$p]+_}" ]]; then
      status_str="${ZL_C[red]:-\033[1;31m}✗ failed${ZL_C[reset]:-\033[0m}"
    else
      local is_enabled=0
      local e
      for e in "${enabled[@]}"; do [[ "$e" == "$p" ]] && is_enabled=1; done
      if (( is_enabled )); then
        status_str="${ZL_C[yellow]:-\033[1;33m}○ enabled (not loaded)${ZL_C[reset]:-\033[0m}"
      else
        status_str="${ZL_C[gray]:-\033[2;37m}○ disabled${ZL_C[reset]:-\033[0m}"
      fi
    fi

    printf "  %-20s %s  %b  %s\n" \
      "${p}" "v${meta_ver}" "$status_str" "${meta_desc:0:50}"
    found=1
  done

  (( found )) || zl::log::info "No plugins found in $ZL_PLUGINS_DIR"
}

# ── Install / remove (conf manipulation) ─────────────────────────────────────
zl::plugin::install() {
  local name="${1:-}"
  local conf="$ZL_HOME/core/plugins.conf"

  [[ -z "$name" ]] && { zl::log::error "Usage: zl install plugin <n>"; return 1; }
  zl::str::is_valid_name "$name" || { zl::log::error "Invalid plugin name: '$name'"; return 1; }
  [[ -f "$ZL_PLUGINS_DIR/$name/init.zsh" ]] || {
    zl::log::error "Plugin '$name' not found (missing $ZL_PLUGINS_DIR/$name/init.zsh)"
    return 1
  }

  if grep -qxF "$name" "$conf" 2>/dev/null; then
    zl::log::ok "$name is already enabled"
    return 0
  fi

  zl::dir::ensure "$(dirname "$conf")"
  printf '%s\n' "$name" >> "$conf"
  zl::log::ok "Enabled: $name — restart shell or run: zl reload"
}

zl::plugin::remove() {
  local name="${1:-}"
  local conf="$ZL_HOME/core/plugins.conf"

  [[ -z "$name" ]] && { zl::log::error "Usage: zl remove plugin <n>"; return 1; }
  zl::str::is_valid_name "$name" || { zl::log::error "Invalid plugin name: '$name'"; return 1; }
  [[ -f "$conf" ]] || { zl::log::warn "plugins.conf not found"; return 0; }

  if [[ "$(uname -s)" == "Darwin" ]]; then
    sed -i '' "/^${name}[[:space:]]*$/d" "$conf" 2>/dev/null || {
      zl::log::error "Failed to update plugins.conf"; return 1
    }
  else
    sed -i "/^${name}[[:space:]]*$/d" "$conf" 2>/dev/null || {
      zl::log::error "Failed to update plugins.conf"; return 1
    }
  fi
  zl::log::ok "Disabled: $name — restart shell or run: zl reload"
}

# ── Auto-bootstrap ────────────────────────────────────────────────────────────
# Called here so plugins load automatically whenever plugin_manager.zsh is
# sourced — whether via loader.zsh (normal startup) or directly.
# loader.zsh also calls zl::plugin::load_all explicitly; the idempotency guards
# inside load_now (ZL_PLUGIN_LOADED) ensure no plugin is executed twice.
zl::plugin::load_all
