# =============================================================================
# ZeroLinux Terminal Framework v2 — config/default.zsh
# Default configuration. Users override in ~/.zerolinuxrc.
#
# All values here serve as defaults; they will NOT overwrite values
# already set by environment variables or ~/.zerolinuxrc.
# =============================================================================

# ── Theme ─────────────────────────────────────────────────────────────────────
: "${ZL_THEME:=zerolinux}"

# ── Logging ───────────────────────────────────────────────────────────────────
# 0=DEBUG 1=INFO 2=WARN 3=ERROR
: "${ZL_LOG_LEVEL:=1}"

# ── Shell behaviour ───────────────────────────────────────────────────────────
# Disable zsh spell-correction (CORRECT / CORRECT_ALL).
# Correction rewrites subcommands like "zl disable" or "git reset" into wrong
# commands. Set to 0 only if you specifically want zsh's correction active.
# 1 = disable autocorrect (default, recommended)
# 0 = leave zsh correction enabled
: "${ZL_DISABLE_AUTOCORRECT:=1}"

# ZL_CORRECT is kept as a legacy alias: 1=on means correction ON (inverse logic).
# Prefer ZL_DISABLE_AUTOCORRECT. Both are honoured; ZL_DISABLE_AUTOCORRECT wins.
: "${ZL_CORRECT:=0}"

# ── Features ──────────────────────────────────────────────────────────────────
: "${ZL_WELCOME_SCREEN:=1}"       # Show welcome on new terminal
: "${ZL_STARTUP_TIME_WARN:=200}"  # Warn if startup > Nms
: "${ZL_LAZY_THRESHOLD:=30}"      # Plugins slower than Nms get lazy-load hint

# ── Arch-specific ─────────────────────────────────────────────────────────────
: "${ZL_ARCH_AUR_HELPER:=}"       # Leave empty for auto-detect

# ── User info (optional, used by some plugins) ────────────────────────────────
: "${ZL_USER_NAME:=${USER:-$(whoami)}}"
: "${ZL_USER_EMAIL:=}"
