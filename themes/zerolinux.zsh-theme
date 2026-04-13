# =============================================================================
# ZeroLinux Theme — zerolinux.zsh-theme
# Requires a Nerd Font for icons. Falls back gracefully without one.
# =============================================================================

# Git info function (only runs inside a git repo)
_zl_theme_git_info() {
  git rev-parse --is-inside-work-tree &>/dev/null || return 0
  local branch
  branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ -z "$branch" ]] && return 0

  local dirty=""
  git diff --quiet 2>/dev/null || dirty="*"
  git diff --cached --quiet 2>/dev/null || dirty="*"

  local untracked=""
  [[ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]] && untracked="?"

  printf " %%F{cyan}  %s%s%s%%f" "$branch" "$dirty" "$untracked"
}

# Build PROMPT
setopt PROMPT_SUBST

PROMPT='%F{blue}╭─%f %F{green}%n@%m%f %F{yellow}%~%f$(_zl_theme_git_info)
%F{blue}╰─%f %F{cyan}❯%f '

RPROMPT='%F{242}%*%f'
