# =============================================================================
# ZeroLinux Plugin: system — commands.zsh
# All functions prefixed: zl_sys_*
# FIX-04: Replaced ZL_C[] array refs with self-contained ANSI codes.
#          ZL_C is only available inside a live ZL zsh session; using it in
#          plugin output functions caused silent empty strings in other contexts.
# =============================================================================

# ── Self-contained colors (no dependency on ZL_C) ────────────────────────────
_SYS_R=$'\033[0m'
_SYS_B=$'\033[1;34m'
_SYS_C=$'\033[1;36m'
_SYS_BD=$'\033[1m'

# ── System aliases ────────────────────────────────────────────────────────────
alias df='df -hT'
alias du='du -sh'
alias free='free -h'
alias ps='ps auxf'
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me && echo'
localip() { ip -br addr | grep -v '^lo' | awk '{print $1, $3}'; }

# Pacman shortcuts (Arch only)
if [[ -f /etc/arch-release ]]; then
  alias pac='sudo pacman'
  alias pacs='sudo pacman -S --needed'
  alias pacr='sudo pacman -Rns'
  alias pacq='pacman -Q'
  alias pacu='sudo pacman -Syu'
  alias pacss='pacman -Ss'
  alias pacclean='sudo pacman -Sc'
fi

# Systemd
alias sc='systemctl'
alias scs='systemctl status'
alias sce='sudo systemctl enable'
alias scd='sudo systemctl disable'
alias scr='sudo systemctl restart'
alias scstart='sudo systemctl start'
alias scstop='sudo systemctl stop'
alias jc='journalctl'
alias jcf='journalctl -f'
alias jce='journalctl -xe'
alias jcu='journalctl -u'

# ── sysinfo — full system overview ────────────────────────────────────────────
sysinfo() {
  printf "\n${_SYS_B}${_SYS_BD}━━━ System Information ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_SYS_R}\n\n"

  # Identity
  printf "  ${_SYS_C}%-16s${_SYS_R}%s\n" "Hostname:"  "$(hostname 2>/dev/null)"
  printf "  ${_SYS_C}%-16s${_SYS_R}%s\n" "User:"      "${USER:-$(id -un)}"
  printf "  ${_SYS_C}%-16s${_SYS_R}%s\n" "OS:"        \
    "$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || uname -s)"
  printf "  ${_SYS_C}%-16s${_SYS_R}%s\n" "Kernel:"    "$(uname -r)"
  printf "  ${_SYS_C}%-16s${_SYS_R}%s\n" "Arch:"      "$(uname -m)"
  printf "  ${_SYS_C}%-16s${_SYS_R}%s\n" "Uptime:"    \
    "$(uptime -p 2>/dev/null | sed 's/up //' || uptime)"
  printf "  ${_SYS_C}%-16s${_SYS_R}%s\n" "Shell:"     \
    "${ZSH_VERSION:+zsh $ZSH_VERSION}${ZSH_VERSION:-${SHELL:-unknown}}"

  # CPU
  printf "\n  ${_SYS_B}${_SYS_BD}CPU:${_SYS_R}\n"
  local cpu_model cpu_cores cpu_load
  cpu_model=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2 | sed 's/^ //')
  cpu_cores=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo '?')
  cpu_load=$(uptime 2>/dev/null | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
  printf "  ${_SYS_C}%-16s${_SYS_R}%s\n" "Model:"     "${cpu_model:-(unknown)}"
  printf "  ${_SYS_C}%-16s${_SYS_R}%s\n" "Cores:"     "${cpu_cores}"
  printf "  ${_SYS_C}%-16s${_SYS_R}%s\n" "Load (1m):" "${cpu_load:-?}"

  # Memory
  printf "\n  ${_SYS_B}${_SYS_BD}Memory:${_SYS_R}\n"
  if [[ -f /proc/meminfo ]]; then
    local mem_t mem_a mem_used_pct
    mem_t=$(awk '/MemTotal/{print $2}'     /proc/meminfo)
    mem_a=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
    mem_used_pct=$(( (mem_t - mem_a) * 100 / mem_t ))
    printf "  ${_SYS_C}%-16s${_SYS_R}%s MiB total, %s MiB free (%s%% used)\n" \
      "RAM:" "$(( mem_t / 1024 ))" "$(( mem_a / 1024 ))" "$mem_used_pct"
  else
    zl::has free && free -h || printf "  (unavailable)\n"
  fi

  # Disk
  printf "\n  ${_SYS_B}${_SYS_BD}Disk:${_SYS_R}\n"
  df -h --output=target,size,used,avail,pcent 2>/dev/null \
    | grep -v tmpfs | grep -v devtmpfs \
    | awk 'NR==1{printf "  %-20s %-8s %-8s %-8s %s\n",$1,$2,$3,$4,$5; next}
           {printf "  %-20s %-8s %-8s %-8s %s\n",$1,$2,$3,$4,$5}' \
  || df -h | head -5

  # Network
  printf "\n  ${_SYS_B}${_SYS_BD}Network:${_SYS_R}\n"
  if command -v ip &>/dev/null; then
    ip -br addr 2>/dev/null | grep -v '^lo' | \
      awk '{printf "  %-16s %s\n", $1, $3}' | head -5
  fi

  printf "\n${_SYS_B}${_SYS_BD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_SYS_R}\n\n"
}

# ── memtop — top memory consumers ─────────────────────────────────────────────
memtop() {
  local n="${1:-10}"
  printf "${_SYS_B}${_SYS_BD}━━━ Top %d Memory Consumers ━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_SYS_R}\n\n" "$n"
  ps aux --sort=-%mem 2>/dev/null | head -$(( n + 1 )) | \
    awk 'NR==1{printf "  %-10s %-6s %-6s %s\n","USER","%CPU","%MEM","COMMAND"; next}
         {printf "  %-10s %-6s %-6s %s\n",$1,$3,$4,$11}'
  printf "\n"
}

# ── cpuwatch — watch CPU / system monitor ─────────────────────────────────────
cpuwatch() {
  if zl::has btop; then
    btop
  elif zl::has htop; then
    htop
  else
    top
  fi
}

# ── portopen — check if a port is open ────────────────────────────────────────
portopen() {
  local host="${1:-}" port="${2:-}"
  if [[ -z "$host" || -z "$port" ]]; then
    echo "Usage: portopen <host> <port>"
    return 1
  fi
  if timeout 3 bash -c ">/dev/tcp/${host}/${port}" 2>/dev/null; then
    printf "✓  %s:%s  OPEN\n"   "$host" "$port"
  else
    printf "✗  %s:%s  CLOSED or unreachable\n" "$host" "$port"
  fi
}

# ── dus — disk usage sorted ───────────────────────────────────────────────────
dus() {
  local target="${1:-.}"
  du -sh -- "$target"/* 2>/dev/null | sort -rh | head -20
}

# ── psg — grep running processes ─────────────────────────────────────────────
psg() {
  [[ -z "${1:-}" ]] && { echo "Usage: psg <pattern>"; return 1; }
  ps aux | grep -i "$1" | grep -v grep
}

# ── fkill — fuzzy process kill ────────────────────────────────────────────────
fkill() {
  zl::has fzf || { echo "fzf not installed"; return 1; }
  local sig="${1:--9}"
  local pid
  pid=$(
    ps -ef | sed 1d \
    | fzf -m \
          --prompt="❯ Kill: " \
          --header="Tab: multi-select  ↵: kill with signal ${sig}" \
    | awk '{print $2}'
  )
  [[ -z "$pid" ]] && return 0
  echo "$pid" | xargs kill "$sig" && echo "✓ Killed: $pid"
}
