<div align="center">

```
███████╗███████╗██████╗  ██████╗ ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
╚══███╔╝██╔════╝██╔══██╗██╔═══██╗██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
  ███╔╝ █████╗  ██████╔╝██║   ██║██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝
 ███╔╝  ██╔══╝  ██╔══██╗██║   ██║██║     ██║██║╚██╗██║██║   ██║ ██╔██╗
███████╗███████╗██║  ██║╚██████╔╝███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
```

# ZeroLinux Terminal

**A Zsh framework that starts fast, isolates plugins, and tells you exactly what's happening.**

![ZeroLinux Terminal Demo](assets/demo.gif)

<img width="1908" height="1012" alt="screenshot" src="https://github.com/user-attachments/assets/3e76259c-fa79-4aca-b03a-a27b08e58c45" />


[![Version](https://img.shields.io/badge/version-2.1.1-blue?style=flat-square)](https://github.com/zerolinux-os/zero_terminal/releases)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Shell](https://img.shields.io/badge/shell-zsh%205.3%2B-orange?style=flat-square)](https://www.zsh.org/)

[Install](#-quick-install) · [Plugins](#-plugins) · [CLI](#-cli-reference) · [Docs](./docs/README.md)

</div>

---

## ⚡ The 60-Second Experience

Watch the demo above to see ZeroLinux in action:

1. **Instant Setup:** Full installation in seconds.
2. **Hot Reload:** `exec zsh` and everything is ready.
3. **Plugin Lifecycle:** Enable/Disable plugins without breaking your shell.
4. **Interactive Tools:** Powered by `fzf` for a modern terminal experience.

---

## 🚀 Quick Install

To replicate the demo, run the following commands:

```bash
# 1. Clone the repository
git clone https://github.com/zerolinux-os/zero_terminal ~/.zerolinux-src

# 2. Run the installer (Unattended mode)
bash ~/.zerolinux-src/install.sh --yes

# 3. Start using it
exec zsh
```

> **Requirements:** zsh ≥ 5.3 · git · curl or wget

---

## 🧪 60-Second Test Drive

After installing, reproduce exactly what you saw in the demo:

**1. Reload your shell and confirm active plugins:**

```bash
exec zsh
echo $ZL_PLUGINS
# git system
```

**2. Try the interactive Git status (`gst`) in a real repo:**

```bash
mkdir ~/zl-test && cd ~/zl-test
git init
touch a.txt
git add .
gst
# ## No commits yet on master
# A  a.txt
```

**3. Browse all available plugins:**

```bash
zl list plugins
```

```
  NAME               VERSION   STATUS       DESCRIPTION
  ──────────────────────────────────────────────────────────────────
  arch               v2.1.1    ○ disabled   Arch Linux pacman and AUR helper utilities (Arch only)
  docker             v2.1.1    ○ disabled   Docker aliases, interactive container management
  example            v1.0.0    ○ disabled   Reference plugin — copy this to create your own
  git                v2.1.1    ● enabled    Interactive Git tools powered by fzf
  system             v2.1.1    ● enabled    System monitoring: sysinfo, memtop, fkill, portopen
```

**4. Test the plugin lifecycle — disable then re-enable:**

```bash
zl disable plugin git
# ✓  Disabled: git  (files kept)

zl enable plugin git
# ✓  Enabled: git
```

**5. Confirm everything still works after re-enabling:**

```bash
cd ~
mkdir zl-demo && cd zl-demo
git init
touch demo.txt
git add .
gst
# ## No commits yet on master
# A  demo.txt
```

---

## What you get immediately

```
$ zl doctor

━━━ ZeroLinux Doctor ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [PASS] zsh 5.9 (≥ 5.3 required)
  [PASS] Default shell: /bin/zsh
  [PASS] core/loader.zsh
  [PASS] core/plugin_manager.zsh
  [PASS] Plugin: git — v2.1.1 ✓
  [PASS] Plugin: system — v2.1.1 ✓
  [PASS] No dangerous patterns detected
  [PASS] No failed systemd services
  [PASS] Internet: reachable

  PASS: 24   WARN: 0   FAIL: 0
  ✅  System is healthy
```

---

## Plugins

ZeroLinux ships four production-ready plugins. Enable what you need, ignore the rest.

### git

Interactive Git tooling powered by fzf.

```bash
gbr          # fzf branch switcher with live log preview
glog         # interactive commit browser → opens in $PAGER
gstash       # fzf stash manager (pop, drop, preview)
groh         # reset to origin/current-branch safely
```

Plus 25 aliases: `gst`, `gaa`, `gcm`, `gco`, `gpf`, `grbi`, `gwip`, and more.

### system

```bash
sysinfo      # full system overview: CPU, RAM, disk, network
memtop       # top N processes by memory
fkill        # fuzzy process kill with multi-select
portopen     # check if host:port is reachable
dus          # disk usage sorted by size
psg          # grep running processes
```

### docker

```bash
dksh         # fzf container picker → exec shell
dkclean      # prune stopped containers, images, volumes, networks
dkip         # print all container IPs
dps / dpsa   # ps / ps -a
dcu / dcd    # compose up -d / compose down
```

### arch *(Arch Linux only)*

```bash
zl_arch_orphans   # list or remove orphaned packages
zl_arch_biggest   # top N packages by installed size
pacfzf            # fzf-powered package search + install
```

---

## CLI Reference

```
zl <command> [subcommand] [args]

Plugin management:
  install plugin <n>    Install and enable a plugin
  remove  plugin <n>    Disable a plugin (keeps files)
  enable  plugin <n>    Enable an installed plugin
  disable plugin <n>    Disable without removing
  list    plugins       All plugins with status
  list    installed     Only enabled plugins
  registry list         Browse available plugins

System:
  doctor                Deep health diagnostics
  reload                Reload instructions
  version               Version info
  help                  Show help

Flags:
  --yes, -y             Skip confirmation prompts
  --with-ohmyzsh        Also install Oh My Zsh
  ZL_SAFE_MODE=1 zsh    Start without any plugins
  ZL_LOG_LEVEL=0 zsh    Enable debug output
  ZL_STRICT_SAFETY=1    Block unsafe plugins on load
```

---

## Configuration

Override defaults in `~/.zerolinuxrc` — ZeroLinux sources it automatically:

```zsh
# ~/.zerolinuxrc

# Log level: 0=DEBUG 1=INFO 2=WARN 3=ERROR (default: 1)
ZL_LOG_LEVEL=1

# Spell-correction (setopt CORRECT CORRECT_ALL). Disable if zsh corrects
# subcommands like "zl disable" or "git reset".
ZL_CORRECT=0           # 1=on (default), 0=off

# Block plugins that fail the security scan
ZL_STRICT_SAFETY=1

# Log startup and plugin timing to file (no network)
ZL_TELEMETRY=1
```

### Enable a plugin

```bash
zl enable plugin docker
exec zsh          # or: zl-reload
```

### Write a plugin

Every plugin follows a strict contract. Start from the included reference implementation:

```bash
cp -r ~/.zerolinux/plugins/example ~/.zerolinux/plugins/myplugin
# Edit plugin.zl, init.zsh, commands.zsh
zl install plugin myplugin
```

Plugin contract in brief:

```
plugins/myplugin/
├── plugin.zl        # name, version, description, dependencies
├── init.zsh         # defines plugin_init()
└── commands.zsh     # defines plugin_register_commands()
```

The plugin manager owns the load lifecycle. Never source `commands.zsh` from `init.zsh`.

---

## Security model

Every plugin is scanned before loading. The scanner detects:

- Alias overrides of system commands (`rm`, `sudo`, `cd`, `chmod`, …)
- Function redefinitions of the same commands
- Remote code execution (`curl … | sh` patterns)
- Unsafe `eval` with variable input

```bash
ZL_STRICT_SAFETY=1 zsh   # block on any finding (default: warn only)
```

Plugin functions are isolated: `plugin_init()` and `plugin_register_commands()` are `unfunction`'d after each call, so generic names cannot leak into the global shell namespace.

---

## Safe install and rollback

The installer backs up your existing configuration before touching anything:

```
~/.zerolinux_backup/20250410_143022/
├── zshrc.bak
├── zerolinux_home.bak/
└── restore.sh               ← always generated
```

```bash
bash ~/.zerolinux_backup/20250410_143022/restore.sh
```

Your `.zshrc` is never overwritten — ZeroLinux injects a guarded block:

```zsh
# >>> ZEROLINUX START >>>
export ZL_HOME="$HOME/.zerolinux"
source "$HOME/.zerolinux/core/loader.zsh"
# <<< ZEROLINUX END <<<
```

---

## Uninstall

```bash
bash ~/.zerolinux/uninstall.sh
```

Removes the block from `.zshrc`, deletes `~/.zerolinux`, removes the `zl` symlink. One command, complete reversal.

---

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). The short version:

1. Fork → branch → change → test (`make test`) → PR
2. All PRs run CI automatically
3. New plugins must follow the contract in `plugins/example/`

---

## Acknowledgements

Built with zsh, fzf, and a lot of time spent staring at startup traces. Inspired by the frustrations of oh-my-zsh, the ambitions of zinit, and the simplicity that neither quite reached.

---

<div align="center">

**[⭐ Star this repo](https://github.com/zerolinux-os/zero_terminal)** if ZeroLinux saved you from another slow terminal session.

[Report a bug](https://github.com/zerolinux-os/zero_terminal/issues/new?template=bug_report.yml) · [Request a feature](https://github.com/zerolinux-os/zero_terminal/issues/new?template=feature_request.yml) · [Sponsor](https://github.com/sponsors/zerolinux)

</div>
