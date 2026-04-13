# =============================================================================
# ZeroLinux Plugin: example — init.zsh  (v2.1.1)
# REFERENCE IMPLEMENTATION
#
# Plugin lifecycle (managed entirely by plugin_manager.zsh):
#   1. plugin_manager sources init.zsh
#   2. plugin_manager calls plugin_init()
#   3. plugin_manager sources commands.zsh
#   4. plugin_manager calls plugin_register_commands()
#
# Rules:
#   - Do NOT source commands.zsh here
#   - Do NOT source any other files from init.zsh
#   - Use plugin_init() only for pre-load setup (env checks, var init)
#   - Use plugin_register_commands() for keybinds, completions
# =============================================================================

# ── Optional dependency guard ─────────────────────────────────────────────────
# Uncomment and adapt if your plugin requires external tools:
# if ! zl::has mytool; then
#   zl::log::warn "plugin[example]: 'mytool' not found — disabled"
#   return 0
# fi

plugin_init() {
  zl::log::debug "plugin[example]: init OK"
}

plugin_register_commands() {
  zl::log::debug "plugin[example]: commands registered"
  # Register keybinds or completions here if needed:
  # zle -N my_widget_fn
  # bindkey '^X^E' my_widget_fn
}
