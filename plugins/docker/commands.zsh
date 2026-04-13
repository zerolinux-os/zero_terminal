# =============================================================================
# ZeroLinux Plugin: docker — commands.zsh
# All functions prefixed: zl_dk_*
# =============================================================================

# ── Core aliases ──────────────────────────────────────────────────────────────
alias dk='docker'
alias dkb='docker build'
alias dkimg='docker images'
alias dkpull='docker pull'
alias dkpush='docker push'
alias dkrm='docker rm'
alias dkrmi='docker rmi'
alias dkrun='docker run --rm -it'
alias dkstop='docker stop'
alias dkstart='docker start'
alias dklog='docker logs -f'
alias dkinspect='docker inspect'
alias dkstats='docker stats --no-stream'

# ps variants
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dpsq='docker ps -q'         # quiet: IDs only
alias dpsaq='docker ps -aq'       # all, quiet

# Compose
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcr='docker compose restart'
alias dcl='docker compose logs -f'
alias dcp='docker compose pull'
alias dcb='docker compose build'
alias dce='docker compose exec'
alias dcs='docker compose ps'

# ── zl_dk_shell — interactive container shell ──────────────────────────────────
dksh() {
  zl::has docker || { zl::log::error "docker not found"; return 1; }

  local container="${1:-}"
  local shell_cmd="${2:-sh}"

  if [[ -z "$container" ]]; then
    # fzf picker if no container specified
    if zl::has fzf; then
      container=$(
        docker ps --format "{{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null \
        | fzf --ansi \
              --prompt="❯ Container: " \
              --header="Select a running container" \
              --preview='docker inspect $(echo {} | awk "{print \$1}") 2>/dev/null | head -40' \
              --preview-window='right:50%' \
        | awk '{print $1}'
      )
      [[ -z "$container" ]] && return 0
    else
      echo "Usage: dksh <container> [shell]"
      echo "Running containers:"
      docker ps --format "  {{.Names}}  ({{.Image}})"
      return 1
    fi
  fi

  zl::log::info "Entering container: $container (shell: $shell_cmd)"
  docker exec -it "$container" "$shell_cmd"
}

# ── dkclean — prune stopped containers, dangling images, unused networks ───────
dkclean() {
  zl::has docker || return 1
  echo "Docker Cleanup"
  echo "─────────────"
  echo "Removing stopped containers..."
  docker container prune -f 2>/dev/null && echo "  ✓ Containers"
  echo "Removing dangling images..."
  docker image prune -f 2>/dev/null && echo "  ✓ Images"
  echo "Removing unused networks..."
  docker network prune -f 2>/dev/null && echo "  ✓ Networks"
  echo "Removing unused volumes..."
  docker volume prune -f 2>/dev/null && echo "  ✓ Volumes"
  echo ""
  echo "After cleanup:"
  docker system df 2>/dev/null || true
}

# ── dkip — print container IP addresses ───────────────────────────────────────
dkip() {
  docker inspect \
    --format='{{.Name}} → {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
    $(docker ps -q 2>/dev/null) 2>/dev/null \
  | sed 's|^/||'
}

# ── zl_dk_running — check if a container is running ───────────────────────────
zl_dk_running() {
  local name="${1:-}"
  [[ -z "$name" ]] && return 1
  docker inspect --format='{{.State.Running}}' "$name" 2>/dev/null | grep -q 'true'
}
