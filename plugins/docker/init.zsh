# =============================================================================
# ZeroLinux Plugin: docker — init.zsh  (v2.1.1)
# =============================================================================

if ! zl::has docker; then
  zl::log::debug "plugin[docker]: docker not found — plugin disabled"
  return 0
fi

plugin_init() {
  zl::log::debug "plugin[docker]: init OK"
  # Non-fatal daemon check — aliases still load even if daemon is down
  if ! docker info &>/dev/null 2>&1; then
    zl::log::warn "plugin[docker]: daemon not running or no permission"
  fi
}

plugin_register_commands() {
  zl::log::debug "plugin[docker]: commands registered"
}
