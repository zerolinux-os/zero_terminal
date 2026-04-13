# =============================================================================
# ZeroLinux Plugin: git — init.zsh  (v2.1.1)
#
# Contract v2.1:
#   plugin_init()              — called by plugin_manager AFTER sourcing this file
#   plugin_register_commands() — called by plugin_manager AFTER sourcing commands.zsh
#
# NOTE: Do NOT source commands.zsh here.
#       plugin_manager.zsh owns the full load lifecycle:
#         1. source init.zsh
#         2. plugin_init()
#         3. source commands.zsh
#         4. plugin_register_commands()
# =============================================================================

# ── Dependency guard ──────────────────────────────────────────────────────────
if ! zl::has git; then
  zl::log::warn "plugin[git]: 'git' not found in PATH — plugin disabled"
  return 0
fi

# ── plugin_init ───────────────────────────────────────────────────────────────
plugin_init() {
  zl::log::debug "plugin[git]: init OK"
}

# ── plugin_register_commands ──────────────────────────────────────────────────
plugin_register_commands() {
  zl::log::debug "plugin[git]: commands registered"
}
