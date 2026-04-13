# Changelog

All notable changes to ZeroLinux Terminal Framework are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.1.1-patch3] — 2026-04-13 — Final Polish

### Fixed
- **`doctor.sh` shell detection**: Replaced unreliable `$SHELL` env var with `getent passwd "$USER" | cut -d: -f7`. `$SHELL` reflects the launching process's shell and stays stale after `chsh` until the next login. `getent` reads `/etc/passwd` directly
- **`install.sh` OMZ auto-install**: Oh My Zsh is no longer installed when `--yes` is passed. Requires explicit `--with-ohmyzsh` flag. Added to `_usage()` documentation
- **Timing rounding**: `integer elapsed_ms=$(( … * 1000 + 0.5 ))` applied in both `plugin_manager.zsh` and `loader.zsh`. Previously truncated; now rounds to nearest millisecond
- **`doctor.sh` safety scanner**: Replaced single weak alias-only pattern with four boolean `grep -Eq` checks (alias overrides, function redefinitions, RCE pipes, eval injection) — matching `plugin_manager.zsh` and `bin/zl` exactly. All three files now use identical `[[:space:]]+` patterns

---

## [2.1.1] — 2026-04-09 — Production Hardening

### Fixed
- **Plugin double-load (CRITICAL)**: All `plugins/*/init.zsh` files previously sourced `commands.zsh` themselves AND `plugin_manager.zsh` sourced it again — causing duplicate alias registration and variable leaks. All `source` calls removed from init.zsh files. `plugin_manager.zsh` is now the sole owner of the load lifecycle
- **Lifecycle order (CRITICAL)**: Enforced strict `init.zsh → plugin_init() → commands.zsh → plugin_register_commands()` sequence in `plugin_manager.zsh`. Previously `commands.zsh` was sourced before `plugin_init()` was called
- **Floating-point arithmetic**: `plugin_manager.zsh` and `loader.zsh` used `$(( float * 1000 ))` and `printf '%.0f'` on `$EPOCHREALTIME` values — fails on locales using comma as decimal separator. Replaced with string-based decimal stripping producing integer milliseconds
- **`zl::version::gte`**: Used `local IFS=.` and direct `(( ))` on split strings — produced "bad floating point constant" on version strings with non-numeric suffixes. Replaced with explicit `IFS='.' read -rA` and `${var%%[^0-9]*}` coercion
- **`cmd_doctor` used `exec`**: `exec "$doctor_script"` replaced the process, preventing the growth-loop message from ever printing. Changed to `bash "$doctor_script"`

### Added
- **`zl registry list`**: Browse bundled plugins via `config/registry.json`; parsed with awk (no jq dependency)
- **`ZL_TELEMETRY=1`**: Log startup and per-plugin timing to log file only — zero network calls
- **`ZL_STRICT_SAFETY=1`**: Block plugin load (not just warn) when security scanner finds issues
- **Growth loop**: `⭐ Star it on GitHub` shown once per session after `zl doctor`, gated by `ZL_STAR_SHOWN`
- **`config/registry.json`**: Local plugin registry with metadata for all bundled plugins

### Security
- Security scanner now identical between `plugin_manager.zsh` and `bin/zl`: alias overrides, function redefinitions, `curl|sh` RCE, `eval $var` — all 4 patterns in both files

---

## [2.1.0] — 2026-04-07 — Release Stabilization

### Fixed
- **BUG-03**: Duplicate `alias gst` in `plugins/git/commands.zsh` — first definition was dead code
- **BUG-04**: `ZL_C[]` array used in `plugins/system/commands.zsh:memtop()` — only populated inside a live ZL session; caused silent empty output. Replaced with self-contained ANSI codes
- **BUG-05**: `local` used at top-level in `core/config.zsh` — invalid outside function scope in strict zsh. Changed to `typeset`
- **BUG-06**: Same `local`-at-toplevel issue in `core/loader.zsh`
- **BUG-07**: Dead `eval`-based lazy stub `install_lazy_stub()` in `plugin_manager.zsh` — was never wired into `load_all()`, consumed memory on every startup, used `eval` unnecessarily. Removed
- **BUG-09**: `install.sh` python3 block passed `$zl_block` as `sys.argv[4]` — any path with spaces caused `IndexError`. Multiline content also broke argv. Fixed: all data passed via environment variables; write made atomic with `os.replace()`
- **BUG-11**: `groh` alias used `$(git branch --show-current)` at alias-definition time (shell startup), not execution time — always produced wrong branch. Converted to function
- **BUG-13**: `compinit` cache check used `date -d@{}` (GNU-only) — silently failed on macOS/non-GNU, causing full security recheck every startup (+100–150ms). Replaced with `stat`-based YYYYMMDD comparison

### Security
- Enhanced safety scanner in `plugin_manager.zsh` — now detects 4 pattern classes:
  - Critical command alias overrides (`rm`, `sudo`, `chmod`, etc.)
  - Critical function redefinitions
  - Remote code execution via `curl/wget | shell`
  - `eval` with variable/user input
- Added `ZL_STRICT_SAFETY=1` mode: blocks plugin load on any security finding
- Safety scan runs before every plugin load, results logged at WARN level

### Added
- `LICENSE` (MIT)
- `Makefile` with targets: `install`, `uninstall`, `doctor`, `package`, `lint`, `clean`
- `CHANGELOG.md` (this file)

### Changed
- `uninstall.sh`: renamed internal variable `local_tmp` → `_zl_tmp`
- `plugin_manager.zsh`: DFS inner function renamed `_zl_pm_visit` to avoid global namespace collision; `unfunction`ed after use
- `core/config.zsh`: compinit section simplified and made cross-platform

---

## [2.0.0] — 2026-04-07 — Initial v2 Release

### Architecture
- Full namespace system: all core functions use `zl::*` double-colon convention
- Plugin contract v2: `plugin.zl` metadata + `plugin_init()` + `plugin_register_commands()`
- Dependency resolver with circular detection (topological sort, DFS)
- Configuration hierarchy: defaults → `~/.zerolinuxrc` → environment variables
- Structured logging: DEBUG / INFO / WARN / ERROR with `ZL_LOG_LEVEL` control
- Safe installer with timestamped backup and `restore.sh` auto-generation
- `zl` CLI: `install/remove/enable/disable/list/doctor/version/help`
- Deep diagnostic `doctor.sh`: 8 sections, PASS/WARN/FAIL with exit codes

### Plugins
- `git`: interactive fzf branch switcher, log browser, stash manager
- `system`: `sysinfo`, `memtop`, `fkill`, `portopen`, `dus`
- `docker`: container shell picker, `dkclean`, compose aliases
- `arch`: pacman/AUR helpers, orphan manager, `pacfzf`
- `example`: fully documented reference implementation

### Breaking changes from v1
- `plugins.conf` entries must match `^[a-zA-Z0-9_-]+$` (enforced)
- Plugin loading now requires `plugin_init()` to be defined in `init.zsh`
- `log_info/log_warn/log_error` kept as backward-compat aliases only
