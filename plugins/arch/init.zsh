# =============================================================================
# ZeroLinux Plugin: arch — init.zsh  (v2.1.1)
# =============================================================================

if [[ ! -f /etc/arch-release ]]; then
  zl::log::debug "plugin[arch]: not Arch Linux — disabled"
  return 0
fi

if ! zl::has pacman; then
  zl::log::warn "plugin[arch]: pacman not found — plugin disabled"
  return 0
fi

plugin_init() {
  zl::log::debug "plugin[arch]: init OK"
}

plugin_register_commands() {
  zl::log::debug "plugin[arch]: commands registered"
}
