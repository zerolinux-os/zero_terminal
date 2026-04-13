# ZeroLinux Terminal — Documentation

**Version:** 2.1.1 | [Changelog](../CHANGELOG.md) | [GitHub](https://github.com/zerolinux/terminal)

---

## Contents

1. [Installation](#installation)
2. [Configuration](#configuration)
3. [Plugins](#plugins)
4. [CLI Reference](#cli-reference)
5. [Writing a Plugin](#writing-a-plugin)
6. [Security Model](#security-model)
7. [Troubleshooting](#troubleshooting)
8. [Architecture](#architecture)

---

## Installation

### Standard install

```bash
git clone https://github.com/zerolinux/terminal ~/.zerolinux-src
bash ~/.zerolinux-src/install.sh
exec zsh
```

### Install with Oh My Zsh

Oh My Zsh is not installed by default. Pass `--with-ohmyzsh` to include it:

```bash
bash ~/.zerolinux-src/install.sh --with-ohmyzsh
```

### Non-interactive (for dotfile bootstraps and CI)

```bash
bash install.sh --yes                   # skip all prompts
bash install.sh --yes --with-ohmyzsh    # skip prompts + install OMZ
bash install.sh --dry-run               # preview without changing anything
```

### Custom install location

```bash
ZL_HOME=/opt/zerolinux bash install.sh
```

### Verifying the release

```bash
sha256sum -c zerolinux-v2.1.1.sha256
# Expected: zerolinux-v2.1.1.tar.gz: OK
```

### What the installer does

1. Checks prerequisites (zsh ≥ 5.3, git, curl/wget, write permissions)
2. Creates a timestamped backup at `~/.zerolinux_backup/<timestamp>/`
3. Writes the framework to `$ZL_HOME` (default: `~/.zerolinux`)
4. Creates a symlink: `~/.local/bin/zl → $ZL_HOME/bin/zl`
5. Injects a guarded block into `~/.zshrc`
6. Generates a `restore.sh` for rollback

The installer never overwrites `~/.zshrc`. It injects a tagged block:

```zsh
# >>> ZEROLINUX START >>>
export ZL_HOME="$HOME/.zerolinux"
source "$HOME/.zerolinux/core/loader.zsh"
# <<< ZEROLINUX END <<<
```

### Uninstalling

```bash
bash ~/.zerolinux/uninstall.sh
```

Removes the block from `.zshrc`, deletes `$ZL_HOME`, removes the `zl` symlink.

### Rollback

```bash
bash ~/.zerolinux_backup/<timestamp>/restore.sh
```

---

## Configuration

### Config hierarchy

Settings are applied in this order (highest priority wins):

1. Environment variables
2. `~/.zerolinuxrc` (user overrides)
3. `$ZL_HOME/config/default.zsh` (shipped defaults)

### All configuration options

```zsh
# ~/.zerolinuxrc

# ── Logging ──────────────────────────────────────────────────────────────────
# 0=DEBUG  1=INFO (default)  2=WARN  3=ERROR
ZL_LOG_LEVEL=1

# Suppress all terminal output (log to file only)
ZL_LOG_SILENT=0

# ── Shell behaviour ───────────────────────────────────────────────────────────
# Spell-correction for commands and arguments (setopt CORRECT CORRECT_ALL).
# Disable if zsh's correction interferes with CLI subcommands such as
# "zl disable", "zl remove", or "git reset".
# 1=on (default), 0=off
ZL_CORRECT=1

# ── Safety ───────────────────────────────────────────────────────────────────
# Block plugin load on any security scanner finding (default: warn only)
ZL_STRICT_SAFETY=0

# ── Startup ──────────────────────────────────────────────────────────────────
# Start without any plugins (useful for debugging)
# Use from command line: ZL_SAFE_MODE=1 zsh
ZL_SAFE_MODE=0

# ── Telemetry ────────────────────────────────────────────────────────────────
# Log startup and plugin timing to file (no network calls)
ZL_TELEMETRY=0

# ── Update channels ──────────────────────────────────────────────────────────
# stable = tagged releases (default)
# beta   = main branch
ZL_CHANNEL=stable
```

### Safe mode

Start a shell without any plugins loaded:

```bash
ZL_SAFE_MODE=1 zsh
# or use the alias:
zl-safe
```

Use this when a plugin is crashing your shell on startup.

---

## Plugins

### Enabling and disabling

```bash
zl enable plugin docker
zl disable plugin docker
exec zsh   # or: source ~/.zshrc
```

Changes take effect on the next shell start.

### The `plugins.conf` file

`~/.zerolinux/core/plugins.conf` is the source of truth for which plugins load:

```
# One plugin name per line. Comments start with #.
git
system
# docker   ← uncomment to enable
```

### Built-in plugins

#### git

Requires `git` in PATH. Enriched with `fzf` if available.

| Command | Description |
|---------|-------------|
| `gbr` | Interactive branch switcher (fzf + live log preview) |
| `glog` | Browse commit history in fzf, open selected in `$PAGER` |
| `gstash` | fzf stash manager: pop, drop, preview diff |
| `groh` | `git reset --hard origin/<current-branch>` (safe) |
| `gst` | `git status -sb` |
| `gaa` | `git add --all` |
| `gcm` | `git commit -m` |
| `gpf` | `git push --force-with-lease` (safer than `--force`) |
| `gwip` | Commit everything as WIP |

#### system

No external requirements. Optional: `fzf`, `btop`, `eza`, `bat`.

| Command | Description |
|---------|-------------|
| `sysinfo` | Full system overview: CPU, RAM, disk, network, uptime |
| `memtop [n]` | Top N processes by memory usage (default: 10) |
| `fkill [signal]` | fzf process picker with multi-select kill |
| `portopen <host> <port>` | Check if a port is reachable |
| `dus [path]` | Disk usage sorted by size |
| `psg <pattern>` | Grep running processes |

#### docker

Requires `docker` in PATH. Daemon availability is checked but not required.

| Command | Description |
|---------|-------------|
| `dksh [container]` | fzf container picker → exec shell |
| `dkclean` | Prune stopped containers, images, volumes, networks |
| `dkip` | Print all running container IPs |
| `dps` / `dpsa` | `docker ps` / `docker ps -a` |
| `dcu` / `dcd` | `docker compose up -d` / `docker compose down` |
| `dklog` | `docker logs -f` |
| `dkstats` | `docker stats --no-stream` |

#### arch *(Arch Linux only)*

Requires `pacman`. Auto-detects `yay`, `paru`, or `pikaur` for AUR.

| Command | Description |
|---------|-------------|
| `zl_arch_orphans [list\|remove]` | List or remove orphaned packages |
| `zl_arch_biggest [n]` | Top N packages by installed size |
| `zl_arch_updates` | Check for available updates via `checkupdates` |
| `pacfzf` | fzf-powered package search and install |

---

## CLI Reference

### `zl install plugin <n>`

Enables a plugin that exists in `$ZL_HOME/plugins/<n>/`. Adds it to `plugins.conf`.
Runs the security scanner before enabling. Prompts for confirmation unless `--yes`.

### `zl remove plugin <n>`

Removes the plugin from `plugins.conf`. Plugin files are kept on disk.

### `zl enable plugin <n>` / `zl disable plugin <n>`

Same as install/remove but without the safety scan prompt. Use for plugins
you've already reviewed.

### `zl list plugins`

Shows all plugins in `$ZL_HOME/plugins/` with version, status (loaded/disabled/failed),
and description.

### `zl list installed`

Shows only enabled plugins with their metadata.

### `zl registry list`

Displays plugins from `$ZL_HOME/config/registry.json`. Requires `jq`.

### `zl doctor`

Runs a full health check across 8 sections:
- System (zsh version, login shell, disk, memory)
- ZeroLinux installation (core files, symlinks, .zshrc block)
- Plugin validation (structure, metadata, dependencies, security)
- Required and optional tools
- Configuration files
- Fonts
- Shell environment
- Arch-specific (orphans, updates)

Exit codes: `0` = healthy, `1` = failures found, `2` = warnings only.

### `zl version`

Shows version, ZL_HOME path, shell version, and plugin count.

### `zl reload`

Prints the commands to reload ZeroLinux in the current session.
The `zl` binary cannot reload its parent shell — use `source ~/.zshrc` or
the `zl-reload` alias instead.

---

## Writing a Plugin

### Step 1: Create the directory structure

```bash
cp -r ~/.zerolinux/plugins/example ~/.zerolinux/plugins/myplugin
```

### Step 2: Edit `plugin.zl`

```ini
name        = myplugin
version     = 1.0.0
description = One sentence describing what this plugin does
dependencies =              # comma-separated plugin names, or empty
requires_zl = 2.1.0
author      = Your Name
```

### Step 3: Edit `init.zsh`

```zsh
# Dependency guard — always return 0 on missing deps (never fail hard)
if ! zl::has mytool; then
  zl::log::warn "plugin[myplugin]: 'mytool' not found — disabled"
  return 0
fi

plugin_init() {
  zl::log::debug "plugin[myplugin]: init"
  # Pre-load setup: environment checks, variable initialization
  # Do NOT source commands.zsh here — the plugin manager does this
}

plugin_register_commands() {
  zl::log::debug "plugin[myplugin]: commands registered"
  # Register keybindings or completions here if needed
}
```

### Step 4: Edit `commands.zsh`

```zsh
# All function names must be prefixed: zl_myplugin_*
# All variables must be local or typeset

alias mp='myplugin-shortcut'

zl_myplugin_main() {
  local arg="${1:-}"
  [[ -z "$arg" ]] && { echo "Usage: zl_myplugin_main <arg>"; return 1; }
  zl::has mytool || { zl::log::error "mytool not found"; return 1; }
  mytool "$arg"
}
```

### Step 5: Install and test

```bash
zl install plugin myplugin
exec zsh
zl list plugins   # confirm it loaded
zl doctor         # confirm no issues
```

### The load lifecycle

The plugin manager controls this order exactly. Do not deviate.

```
1. source init.zsh
2. plugin_init()              ← called and immediately unfunction'd
3. source commands.zsh
4. plugin_register_commands() ← called and immediately unfunction'd
```

`plugin_init` and `plugin_register_commands` are removed from the shell
after each call. This prevents name collisions between plugins.

### Dependency declarations

```ini
# plugin.zl
dependencies = git, system
```

ZeroLinux resolves dependencies with a topological sort and detects circular
dependencies. If `myplugin` depends on `git`, the git plugin loads first.

---

## Security Model

### Plugin isolation

Every plugin function that executes during load (`plugin_init`, `plugin_register_commands`)
is `unfunction`'d immediately after. This means:

- Plugin A cannot call Plugin B's init function
- Generic names like `init` or `setup` cannot leak globally
- A broken plugin does not affect other plugins

### Security scanner

Runs before every plugin load. Detects:

| Pattern | Risk |
|---------|------|
| `alias rm=…` | Replaces system command |
| `function sudo()` | Shadows system command |
| `curl … \| sh` | Remote code execution |
| `eval "$var"` | Arbitrary code execution |

In **warn mode** (default): logs the finding, loads the plugin anyway.
In **strict mode** (`ZL_STRICT_SAFETY=1`): blocks the plugin from loading.

### Startup safety

The loader uses `ZL_SAFE_MODE=1` to skip all plugins:

```bash
ZL_SAFE_MODE=1 zsh   # safe shell for debugging
```

The shell always starts, even if every plugin fails. Failures are logged, not
propagated.

---

## Troubleshooting

### Shell starts slowly

```bash
ZL_LOG_LEVEL=0 ZL_TELEMETRY=1 zsh -i -c exit
```

Debug output will show which plugin or step is slow. Typical causes:
- A plugin that runs a slow command at init time
- `compinit` running a full check (fixed by deleting `~/.zcompdump` once)

### A plugin fails to load

```bash
ZL_LOG_LEVEL=0 zsh -c "source ~/.zerolinux/core/loader.zsh"
```

Look for `[ZL:ERROR]` lines. Common causes:
- External dependency not installed (`zl::has` check at top of `init.zsh`)
- Syntax error in `commands.zsh`
- Plugin directory missing from `$ZL_PLUGINS_DIR`

Disable the offending plugin and restart:

```bash
zl disable plugin <name>
exec zsh
```

### Shell doesn't start at all

```bash
ZL_SAFE_MODE=1 zsh   # starts without any plugins
```

Then identify the problem plugin:

```bash
ZL_LOG_LEVEL=0 ZL_SAFE_MODE=0 zsh 2>&1 | head -30
```

### Rollback the installation

```bash
bash ~/.zerolinux_backup/<timestamp>/restore.sh
```

---

## Architecture

```
~/.zerolinux/
├── VERSION
├── bin/
│   └── zl                    # CLI tool
├── core/
│   ├── loader.zsh             # Entry point — sourced from .zshrc
│   ├── logger.zsh             # Structured logging (DEBUG/INFO/WARN/ERROR)
│   ├── utils.zsh              # Shared utilities (zl::* namespace)
│   ├── plugin_manager.zsh     # Lifecycle, dependency resolution, scanner
│   ├── config.zsh             # Shell environment, aliases, completions
│   └── welcome.zsh            # Startup screen (once per session)
├── config/
│   ├── default.zsh            # Shipped defaults
│   ├── plugins.conf           # Enabled plugin list
│   └── registry.json          # Plugin registry
├── plugins/
│   └── <name>/
│       ├── plugin.zl          # Metadata
│       ├── init.zsh           # plugin_init()
│       └── commands.zsh       # Aliases and functions
├── themes/
│   └── zerolinux.zsh-theme
└── logs/
    └── zl.log
```

### Startup sequence

```
.zshrc
  └── source loader.zsh
        ├── source logger.zsh
        ├── source utils.zsh
        ├── source plugin_manager.zsh
        ├── source config.zsh
        │     ├── source config/default.zsh
        │     └── source ~/.zerolinuxrc
        ├── welcome screen (once)
        └── zl::plugin::load_all
              ├── read plugins.conf
              ├── resolve dependency order (topological sort)
              └── for each plugin:
                    ├── validate structure
                    ├── check ZL version compatibility
                    ├── run security scanner
                    ├── source init.zsh
                    ├── call plugin_init()  → unfunction
                    ├── source commands.zsh
                    └── call plugin_register_commands() → unfunction
```

### Namespace conventions

| Scope | Convention |
|-------|-----------|
| Core public API | `zl::module::function` |
| Core private helpers | `_zl::module::function` |
| Plugin functions | `zl_pluginname_function` |
| Global state variables | `ZL_UPPERCASE` |
| Temp/loop variables | `_zl_lowercase` |
