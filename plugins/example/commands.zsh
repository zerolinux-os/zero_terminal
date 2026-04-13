# =============================================================================
# ZeroLinux Plugin: example — commands.zsh
# Add aliases and functions here.
#
# Rules:
#   - All function names: zl_example_*   (prevents collision)
#   - All variables:      local/typeset   (prevents leakage)
#   - No bare `eval`
#   - Every function has an early return guard on bad input
#   - Use zl::has before calling any optional tool
# =============================================================================

# ── Example alias ─────────────────────────────────────────────────────────────
# alias myalias='echo Hello from example plugin'

# ── Example function ──────────────────────────────────────────────────────────
zl_example_hello() {
  local name="${1:-World}"
  echo "Hello, ${name}! (from ZeroLinux example plugin)"
  zl::log::debug "zl_example_hello called with: $name"
}

# ── Example function with dependency guard ────────────────────────────────────
zl_example_fzf_demo() {
  if ! zl::has fzf; then
    zl::log::warn "zl_example_fzf_demo requires fzf"
    return 1
  fi
  printf '%s\n' one two three | fzf --prompt="❯ Choose: "
}
