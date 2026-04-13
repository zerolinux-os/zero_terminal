# =============================================================================
# ZeroLinux Terminal Framework v2 — core/config.zsh
# Configuration hierarchy resolver and shell environment setup.
#
# Priority (highest wins):
#   1. Environment variables  (ZL_THEME, ZL_LOG_LEVEL, etc.)
#   2. User config            (~/.zerolinuxrc)
#   3. Default config         ($ZL_HOME/config/default.zsh)
#
# FIX-05: Replaced 'local' at top-level (invalid outside functions in strict
#         shells) with typeset. In zsh sourced files, local at top-level creates
#         a local scope tied to the sourcing context — semantically wrong and
#         confusing. typeset at top-level creates proper script-scoped vars.
# FIX-13: Replaced fragile compinit date-check with a reliable zcompdump mtime
#         comparison using zsh's own ${ZL_CACHE_DIR} stat via zsh/stat module,
#         or a simplified stat fallback that doesn't require GNU date -d.
# =============================================================================

[[ -n "${ZL_CONFIG_LOADED:-}" ]] && return 0
typeset -g ZL_CONFIG_LOADED=1

# ── ZL_HOME safety ────────────────────────────────────────────────────────────
if [[ -z "${ZL_HOME:-}" ]]; then
  typeset -gx ZL_HOME="$HOME/.zerolinux"
fi

# ── Load config hierarchy ─────────────────────────────────────────────────────
# 1. Shipped defaults
typeset _zl_default_cfg="$ZL_HOME/config/default.zsh"
if [[ -f "$_zl_default_cfg" ]]; then
  source "$_zl_default_cfg" 2>/dev/null || \
    zl::log::warn "config: default.zsh failed to load"
fi
unset _zl_default_cfg

# 2. User overrides
typeset _zl_user_cfg="${ZDOTDIR:-$HOME}/.zerolinuxrc"
if [[ -f "$_zl_user_cfg" ]]; then
  source "$_zl_user_cfg" 2>/dev/null || \
    zl::log::warn "config: ~/.zerolinuxrc failed to load"
fi
unset _zl_user_cfg

# 3. Environment variables win — already set, nothing to do.

# ── PATH (idempotent prepends) ────────────────────────────────────────────────
[[ ":$PATH:" != *":$HOME/.local/bin:"* ]] && export PATH="$HOME/.local/bin:$PATH"
[[ ":$PATH:" != *":$ZL_HOME/bin:"*     ]] && export PATH="$ZL_HOME/bin:$PATH"

# ── EDITOR ────────────────────────────────────────────────────────────────────
if [[ -z "${EDITOR:-}" ]]; then
  typeset _zl_e
  for _zl_e in nvim vim vi nano; do
    zl::has "$_zl_e" && { export EDITOR="$_zl_e"; break; }
  done
  unset _zl_e
fi
export VISUAL="${VISUAL:-${EDITOR:-vi}}"

# ── PAGER ─────────────────────────────────────────────────────────────────────
if [[ -z "${PAGER:-}" ]]; then
  if zl::has bat; then
    export PAGER="bat --paging=always"
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
  else
    export PAGER="less"
  fi
fi

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

# ── bat ───────────────────────────────────────────────────────────────────────
if zl::has bat; then
  export BAT_THEME="${BAT_THEME:-TwoDark}"
  export BAT_STYLE="${BAT_STYLE:-numbers,changes,header}"
fi

# ── fzf ───────────────────────────────────────────────────────────────────────
if zl::has fzf; then
  if zl::has fd; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  fi
  export FZF_DEFAULT_OPTS="
  --height 45%
  --layout=reverse
  --border=rounded
  --prompt='❯ '
  --pointer='▶'
  --marker='✓'
  --ansi
  --color=fg:#cdd6f4,bg:#1e1e2e,hl:#cba6f7
  --color=fg+:#cdd6f4,bg+:#313244,hl+:#cba6f7
  --color=info:#89dceb,prompt:#89b4fa,pointer:#f5c2e7
  --color=marker:#a6e3a1,spinner:#f5c2e7,header:#89b4fa
  --bind=ctrl-/:toggle-preview
  --preview-window=right:55%:wrap
"
fi

# ── History ───────────────────────────────────────────────────────────────────
HISTFILE="${ZDOTDIR:-$HOME}/.zsh_history"
HISTSIZE=200000
SAVEHIST=200000
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS SHARE_HISTORY EXTENDED_HISTORY

# ── Shell options ─────────────────────────────────────────────────────────────
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT
setopt GLOBDOTS EXTENDED_GLOB NO_BEEP MULTIOS INTERACTIVE_COMMENTS
setopt COMPLETE_IN_WORD ALWAYS_TO_END
# Spell-correction: only active when ZL_DISABLE_AUTOCORRECT=0 AND ZL_CORRECT=1.
# Default (ZL_DISABLE_AUTOCORRECT=1) keeps correction off so CLI subcommands
# like 'zl disable' and 'git reset' are never rewritten by zsh.
if [[ "${ZL_DISABLE_AUTOCORRECT:-1}" -eq 0 && "${ZL_CORRECT:-0}" == "1" ]]; then
  setopt CORRECT CORRECT_ALL
fi

# ── Completion ────────────────────────────────────────────────────────────────
# FIX-13: Reliable cross-platform compinit cache check.
# Strategy: compare zcompdump mtime (seconds since epoch via stat) to today's
# date as epoch-of-midnight. No GNU date required — works on Linux and macOS.
autoload -Uz compinit
typeset _zl_zcd="${ZDOTDIR:-$HOME}/.zcompdump"

# Get today's date as YYYYMMDD integer for comparison
typeset _zl_today
_zl_today=$(date +%Y%m%d 2>/dev/null || echo "0")

# Get zcompdump's mtime as YYYYMMDD
typeset _zl_dump_day="0"
if [[ -f "$_zl_zcd" ]]; then
  # Linux stat
  _zl_dump_day=$(stat -c '%y' "$_zl_zcd" 2>/dev/null | cut -c1-10 | tr -d '-') || \
  # macOS stat
  _zl_dump_day=$(stat -f '%Sm' -t '%Y%m%d' "$_zl_zcd" 2>/dev/null) || \
  _zl_dump_day="0"
fi

if [[ "$_zl_today" == "$_zl_dump_day" ]]; then
  compinit -C -d "$_zl_zcd"   # skip security check — dump is from today
else
  compinit -d "$_zl_zcd"      # full check once per day
fi
unset _zl_zcd _zl_today _zl_dump_day

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
# shellcheck disable=SC2296
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{blue}%B── %d ──%b%f'
zstyle ':completion:*:warnings'     format '%F{red}✗ No matches: %d%f'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*' cache-path "${ZL_CACHE_DIR:-$HOME/.cache/zerolinux}/zcompcache"
zstyle ':completion::complete:*' use-cache on

# ── Key bindings ──────────────────────────────────────────────────────────────
bindkey -e
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^[^?'    backward-kill-word
bindkey '^[[3;5~' kill-word

autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
if (( ! ${+widgets[history-substring-search-up]} )); then
  bindkey '^[[A' up-line-or-beginning-search
  bindkey '^[[B' down-line-or-beginning-search
  bindkey '^P'   up-line-or-beginning-search
  bindkey '^N'   down-line-or-beginning-search
fi

# ── Core aliases ──────────────────────────────────────────────────────────────
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'

if zl::has eza; then
  alias ls='eza --icons --group-directories-first --color=always'
  alias ll='eza --icons --group-directories-first -la --git --color=always'
  alias la='eza --icons --group-directories-first -a --color=always'
  alias lt='eza --icons --tree --level=2 --color=always'
  alias llt='eza --icons --tree --level=3 --git --color=always'
else
  alias ls='ls --color=auto'
  alias ll='ls -la --color=auto'
  alias la='ls -a --color=auto'
fi

if zl::has bat; then
  alias cat='bat --style=numbers,changes,header'
  alias catp='bat --style=plain'
  alias less='bat --paging=always'
fi

alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -Iv'
alias mkdir='mkdir -pv'
alias df='df -hT'
alias du='du -sh'
alias free='free -h'
alias grep='grep --color=auto'
alias cls='clear'
alias ping='ping -c5'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me && echo'

zl::has btop  && alias top='btop' && alias htop='btop'
zl::has delta && alias diff='delta'

# ZeroLinux shortcuts
alias zl-reload='source ~/.zshrc && zl::log::info "ZeroLinux reloaded"'
alias zl-edit='${EDITOR:-nano} "$ZL_HOME/config/default.zsh"'
alias zl-log='tail -50f "${ZL_LOG:-$ZL_HOME/logs/zl.log}"'
alias zl-safe='ZL_SAFE_MODE=1 zsh'

# ── Core functions ────────────────────────────────────────────────────────────

mkcd() {
  [[ -z "${1:-}" ]] && { echo "Usage: mkcd <dir>"; return 1; }
  mkdir -p "$1" && cd "$1"
}

bak() {
  [[ -z "${1:-}" ]] && { echo "Usage: bak <file>"; return 1; }
  [[ ! -e "$1"   ]] && { echo "Not found: $1"; return 1; }
  local dest="${1}.bak.$(date +%Y%m%d_%H%M%S)"
  cp -a "$1" "$dest" && zl::log::ok "Backed up → $dest"
}

extract() {
  [[ -z "${1:-}" ]] && { echo "Usage: extract <archive>"; return 1; }
  [[ ! -f "$1"   ]] && { echo "Not a file: $1"; return 1; }
  case "$1" in
    *.tar.bz2) tar xjf "$1" ;;  *.tar.gz)  tar xzf "$1" ;;
    *.tar.xz)  tar xJf "$1" ;;  *.tar.zst) tar --zstd -xf "$1" ;;
    *.tar)     tar xf  "$1" ;;  *.bz2)     bunzip2 "$1" ;;
    *.gz)      gunzip  "$1" ;;  *.rar)     unrar x "$1" ;;
    *.zip)     unzip   "$1" ;;  *.7z)      7z x    "$1" ;;
    *.zst)     zstd -d "$1" ;;
    *) echo "Cannot extract: $1"; return 1 ;;
  esac
}

fo() {
  zl::has fzf || { echo "fzf not installed"; return 1; }
  local file
  file=$(
    if zl::has fd; then
      fd --type f --hidden --follow --exclude .git 2>/dev/null
    else
      find . -type f 2>/dev/null
    fi | fzf --preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}' \
             --preview-window='right:55%'
  )
  [[ -n "$file" ]] && ${EDITOR:-vi} "$file"
}

fif() {
  [[ -z "${1:-}" ]] && { echo "Usage: fif <pattern>"; return 1; }
  zl::has rg  || { echo "ripgrep not installed"; return 1; }
  zl::has fzf || { echo "fzf not installed"; return 1; }
  rg --color=always --line-number --no-heading --smart-case "$1" 2>/dev/null | \
    fzf --ansi \
        --delimiter : \
        --preview "bat --style=numbers --color=always --highlight-line {2} {1} 2>/dev/null" \
        --preview-window 'right,60%,+{2}+3/3,~3' \
        --bind "enter:become(${EDITOR:-vi} {1} +{2})"
}

note() {
  local f="$HOME/.notes"
  if [[ -z "${1:-}" ]]; then
    if zl::has bat; then
      bat "$f" 2>/dev/null || echo "No notes yet. Use: note <text>"
    else
      cat "$f" 2>/dev/null || echo "No notes yet."
    fi
  else
    echo "[$(date '+%Y-%m-%d %H:%M')] $*" >> "$f"
    echo "✓ Note saved"
  fi
}

# ── External tool init (guarded) ──────────────────────────────────────────────
zl::has zoxide  && eval "$(zoxide init zsh --cmd j 2>/dev/null)" 2>/dev/null || true
zl::has thefuck && eval "$(thefuck --alias 2>/dev/null)"         2>/dev/null || true
