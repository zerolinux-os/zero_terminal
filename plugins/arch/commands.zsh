# =============================================================================
# ZeroLinux Plugin: arch — commands.zsh
# Pacman + AUR helpers. All functions prefixed: zl_arch_*
# =============================================================================

# ── Detect AUR helper ─────────────────────────────────────────────────────────
_ZL_AUR_HELPER=""
for _h in yay paru pikaur; do
  command -v "$_h" &>/dev/null && _ZL_AUR_HELPER="$_h" && break
done
unset _h

# ── Pacman aliases ────────────────────────────────────────────────────────────
alias pac='sudo pacman'
alias paci='sudo pacman -S --needed'
alias pacr='sudo pacman -Rns'
alias pacu='sudo pacman -Syu'
alias pacs='pacman -Ss'
alias pacq='pacman -Q'
alias pacqi='pacman -Qi'
alias pacql='pacman -Ql'
alias pacqo='pacman -Qo'
alias pacclean='sudo pacman -Sc'
alias paclean2='sudo pacman -Scc'

# AUR helpers (if available)
if [[ -n "$_ZL_AUR_HELPER" ]]; then
  alias auri="${_ZL_AUR_HELPER} -S"
  alias aurs="${_ZL_AUR_HELPER} -Ss"
  alias auru="${_ZL_AUR_HELPER} -Sua"
fi

# ── zl_arch_orphans — list/remove orphaned packages ───────────────────────────
zl_arch_orphans() {
  local action="${1:-list}"
  local orphans
  orphans=$(pacman -Qtdq 2>/dev/null)

  if [[ -z "$orphans" ]]; then
    echo "✓  No orphaned packages"
    return 0
  fi

  case "$action" in
    list)
      echo "Orphaned packages:"
      echo "$orphans" | awk '{print "  · " $0}'
      ;;
    remove)
      echo "Removing orphaned packages..."
      echo "$orphans" | sudo pacman -Rns --noconfirm - && echo "✓ Done"
      ;;
    *)
      echo "Usage: zl_arch_orphans [list|remove]"
      ;;
  esac
}

# ── zl_arch_biggest — N largest installed packages ────────────────────────────
zl_arch_biggest() {
  local n="${1:-20}"
  expac -H M '%m\t%n' 2>/dev/null | sort -rh | head -"$n" | \
    awk '{printf "  %-8s %s\n", $1, $2}' \
  || pacman -Qi | awk '/^Name/{name=$3} /^Installed Size/{print $4$5, name}' \
     | sort -rh | head -"$n"
}

# ── zl_arch_updates — check for available updates ────────────────────────────
zl_arch_updates() {
  if command -v checkupdates &>/dev/null; then
    local updates
    updates=$(checkupdates 2>/dev/null)
    if [[ -z "$updates" ]]; then
      echo "✓  System is up to date"
    else
      local count
      count=$(echo "$updates" | wc -l)
      echo "Updates available: $count package(s)"
      echo "$updates" | head -20
    fi
  else
    echo "checkupdates not found (install pacman-contrib)"
  fi
}

# ── pacfzf — fzf-powered package search and install ───────────────────────────
pacfzf() {
  zl::has fzf || { echo "fzf required"; return 1; }
  local pkg
  pkg=$(
    pacman -Slq 2>/dev/null \
    | fzf --multi \
          --prompt="❯ Package: " \
          --header="Tab: multi-select  ↵: install" \
          --preview='pacman -Si {} 2>/dev/null || pacman -Qi {} 2>/dev/null' \
          --preview-window='right:55%'
  )
  [[ -z "$pkg" ]] && return 0
  echo "Installing: $pkg"
  sudo pacman -S --needed $pkg
}
