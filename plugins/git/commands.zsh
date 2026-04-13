# =============================================================================
# ZeroLinux Plugin: git — commands.zsh
# Aliases, interactive fzf tools, and helper functions.
# All functions prefixed: zl_git_*
# All variables: local or typeset
# =============================================================================

# ── Core aliases ──────────────────────────────────────────────────────────────
alias g='git'
alias gst='git status -sb'
alias ga='git add'
alias gaa='git add --all'
alias gcm='git commit -m'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gcp='git cherry-pick'
alias gd='git diff'
alias gds='git diff --staged'
alias gf='git fetch --all --prune'
alias gl='git pull'
alias glo='git log --oneline --graph --decorate --all'
alias gp='git push'
alias gpf='git push --force-with-lease'  # safer than --force
alias grb='git rebase'
alias grbi='git rebase -i'
alias grbc='git rebase --continue'
alias grba='git rebase --abort'
alias grhh='git reset --hard HEAD'
# FIX-11: groh was an alias with command substitution at define-time.
# Must be a function so 'git branch --show-current' runs at call time.
groh() {
  local branch
  branch=$(git branch --show-current 2>/dev/null) || branch="HEAD"
  [[ -z "$branch" ]] && { zl::log::error "groh: cannot determine current branch"; return 1; }
  git reset --hard "origin/${branch}"
}
alias gstp='git stash pop'
alias gstl='git stash list'
alias gsts='git stash show --text'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gcl='git clone'
alias gwip='git add -A && git commit -m "WIP: [skip ci]"'
alias gunwip='git log -n 1 | grep -q "WIP:" && git reset HEAD~1 || true'
zl::has lazygit && alias lg='lazygit'

# ── zl_git_in_repo ─────────────────────────────────────────────────────────────
# Returns 0 if inside a git repository
zl_git_in_repo() {
  git rev-parse --is-inside-work-tree &>/dev/null
}

# ── gbr — interactive branch switcher ─────────────────────────────────────────
gbr() {
  zl::has git || { zl::log::error "git not installed"; return 1; }
  zl_git_in_repo || { zl::log::error "Not inside a git repository"; return 1; }
  zl::has fzf  || { zl::log::error "fzf not installed (required for gbr)"; return 1; }

  local branch
  branch=$(
    git branch -a --color=always 2>/dev/null \
      | grep -v HEAD \
      | fzf --ansi \
            --prompt="❯ Branch: " \
            --header="↵ checkout  Ctrl+/ toggle preview" \
            --preview='git log --oneline --decorate --graph -20 \
                       $(echo {} | sed "s|remotes/origin/||" | tr -d " *") 2>/dev/null' \
            --preview-window='right:60%'
  )
  [[ -z "$branch" ]] && return 0
  local clean_branch
  clean_branch=$(echo "$branch" | sed 's|remotes/origin/||' | tr -d ' *')
  git checkout "$clean_branch"
}

# ── glog — interactive git log browser ────────────────────────────────────────
glog() {
  zl::has git || return 1
  zl::has fzf || { git log --oneline --graph --decorate --all "$@"; return; }
  zl_git_in_repo || { zl::log::error "Not inside a git repository"; return 1; }

  git log \
    --color=always \
    --format="%C(cyan)%h%Creset %C(magenta)%an%Creset %C(yellow)%ar%Creset  %s  %C(green dim)%D%Creset" \
    "$@" \
  | fzf --ansi \
        --no-sort \
        --reverse \
        --prompt="❯ Commit: " \
        --header="↵ show full  Ctrl+/ preview diff" \
        --preview='git show --color=always $(echo {} | awk "{print \$1}") 2>/dev/null' \
        --preview-window='right:60%' \
        --bind="enter:execute(git show --color=always {1} | ${PAGER:-less})"
}

# ── gstash — interactive stash manager ────────────────────────────────────────
gstash() {
  zl::has git || return 1
  zl::has fzf || { git stash list; return; }
  zl_git_in_repo || { zl::log::error "Not inside a git repository"; return 1; }

  local choice
  choice=$(
    git stash list 2>/dev/null \
    | fzf --ansi \
          --prompt="❯ Stash: " \
          --header="↵ pop  Ctrl+D drop  Ctrl+/ preview" \
          --preview='git stash show -p $(echo {} | cut -d: -f1) 2>/dev/null' \
          --preview-window='right:60%' \
          --bind="ctrl-d:execute(git stash drop $(echo {} | cut -d: -f1))+reload(git stash list)"
  )
  [[ -z "$choice" ]] && return 0
  local stash_id
  stash_id=$(echo "$choice" | cut -d: -f1)
  git stash pop "$stash_id"
}

# ── zl_git_branch — print current branch (safe) ───────────────────────────────
zl_git_branch() {
  git branch --show-current 2>/dev/null || \
  git rev-parse --abbrev-ref HEAD 2>/dev/null || \
  echo "(no branch)"
}
