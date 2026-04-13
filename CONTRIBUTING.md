# Contributing to ZeroLinux Terminal

Thank you for taking the time to contribute. ZeroLinux is a small, focused project
and every contribution — a bug fix, a new plugin, a documentation correction —
makes it better for everyone.

---

## Table of contents

- [Getting started](#getting-started)
- [How to contribute](#how-to-contribute)
  - [Reporting bugs](#reporting-bugs)
  - [Suggesting features](#suggesting-features)
  - [Submitting a pull request](#submitting-a-pull-request)
- [Plugin development](#plugin-development)
- [Code standards](#code-standards)
- [Testing](#testing)
- [Commit messages](#commit-messages)
- [Code of conduct](#code-of-conduct)

---

## Getting started

```bash
# Fork the repo on GitHub, then:
git clone https://github.com/YOUR_USERNAME/zero_terminal.git
cd zero_terminal
make test    # verify everything passes before you change anything
```

**Requirements for development:**

- zsh ≥ 5.3
- bash (for `make test` and scripts)
- git
- Optional: `shellcheck` for linting (`make lint`)

---

## How to contribute

### Reporting bugs

Use the [bug report template](https://github.com/zerolinux-os/zero_terminal/issues/new?template=bug_report.yml).

Before opening an issue:

1. Run `zl doctor` and include the output.
2. Check [existing issues](https://github.com/zerolinux-os/zero_terminal/issues) — the bug may already be reported.
3. Include your zsh version (`zsh --version`), OS, and the exact steps to reproduce.

A minimal reproduction is more valuable than a long description. If you can
reproduce the bug in a fresh shell (`zsh --no-rcs`), include that.

### Suggesting features

Use the [feature request template](https://github.com/zerolinux-os/zero_terminal/issues/new?template=feature_request.yml).

Features are accepted when they fit one of three principles:

- Make the shell start faster or stay silent
- Improve plugin safety or isolation
- Give the user more control and visibility

Features that add bloat, require external services, or duplicate functionality
that belongs in the plugin (not the framework) are respectfully declined.

### Submitting a pull request

1. **Open an issue first** for anything beyond a typo or obvious bug fix. This
   avoids wasted effort if the change direction is wrong.

2. **Branch from `main`:**

   ```bash
   git checkout -b fix/describe-your-change
   # or: feat/plugin-name, docs/section-name
   ```

3. **Make the smallest change that solves the problem.** Do not refactor
   unrelated code in the same PR.

4. **Run the test suite before pushing:**

   ```bash
   make test        # syntax validation on all shell files
   make check-perms # verify executable bits
   ```

5. **Push and open a PR against `main`.** Fill in the PR template completely —
   sections left blank slow down review.

6. CI runs automatically. Do not merge until CI is green.

---

## Plugin development

New plugins are welcome. The bar is: useful to more than one person, follows
the contract, and passes the security scanner cleanly.

### Start from the reference implementation

```bash
cp -r plugins/example plugins/myplugin
```

### Plugin contract (mandatory)

Every plugin **must** have exactly these three files:

```
plugins/myplugin/
├── plugin.zl        # Metadata
├── init.zsh         # Defines plugin_init()
└── commands.zsh     # Defines plugin_register_commands()  [can be minimal]
```

**`plugin.zl` format:**

```ini
name        = myplugin
version     = 1.0.0
description = One sentence description of what this plugin does
dependencies =
requires_zl = 2.1.0
author      = Your Name
```

**`init.zsh` rules:**

- Define `plugin_init()` — called by the plugin manager after sourcing
- Define `plugin_register_commands()` — called after `commands.zsh` is sourced
- **Do NOT source `commands.zsh` yourself** — the plugin manager owns the lifecycle
- Guard against missing dependencies at the top:

```zsh
if ! zl::has mytool; then
  zl::log::warn "plugin[myplugin]: 'mytool' not found — disabled"
  return 0
fi
```

**`commands.zsh` rules:**

- All function names must be prefixed: `zl_myplugin_*` (no namespace pollution)
- All variables must be `local` or `typeset` (no global leakage)
- No bare `eval`
- Check for optional tools with `zl::has` before calling them

### The load lifecycle (read this)

The plugin manager controls this order exactly:

```
1. source init.zsh
2. plugin_init()              ← unfunction'd after call
3. source commands.zsh
4. plugin_register_commands() ← unfunction'd after call
```

Breaking this order will cause your PR to be rejected.

### Passing the security scanner

Your plugin must not match any of these patterns:

```
alias (rm|sudo|cd|chmod|…) =   ← overrides a system command
function (rm|sudo|cd|…)        ← redefines a system command
curl … | sh                    ← remote code execution
eval "$variable"               ← unsafe eval
```

Run the scanner manually before submitting:

```bash
ZL_STRICT_SAFETY=1 zsh -c "
  source ~/.zerolinux/core/loader.zsh
  zl::plugin::safety_scan myplugin
"
```

---

## Code standards

### Naming

| Scope           | Convention          | Example                  |
|-----------------|---------------------|--------------------------|
| Core functions  | `zl::module::name`  | `zl::plugin::load_now`   |
| Plugin functions| `zl_pluginname_name`| `zl_git_branch`          |
| Private helpers | `_zl::module::name` | `_zl::log::write`        |
| Global variables| `ZL_UPPERCASE`      | `ZL_PLUGIN_LOADED`       |
| Temp variables  | `typeset _zl_name`  | `typeset _zl_t0`         |

### Zsh-specific rules

- Never use `local` at top-level scope in sourced files — use `typeset`
- Use `typeset -F` for float variables (timing)
- Use `integer` for integer casts from float (`integer ms=$(( float * 1000 + 0.5 ))`)
- Use `zl::has` instead of `command -v` for tool checks
- Guard all file operations: check existence before sourcing, reading, or writing

### Output rules

- Core modules must produce **zero stdout** at startup with default `ZL_LOG_LEVEL=1`
- Use `zl::log::debug` for anything that fires on startup
- `zl::log::info` is for explicit user actions only (not background loading)
- Never use `echo` for output that fires automatically — only for user-triggered functions

### Error handling

- Never use `set -e` in sourced files — it will kill the user's shell on the first error
- Use explicit error handling: `command || { zl::log::error "…"; return 1; }`
- Every function that can fail must return a meaningful exit code (0 = success, 1 = failure)
- Errors in plugins must never propagate to crash the shell

---

## Testing

```bash
make test        # bash -n syntax check on every .sh and .zsh file
make lint        # shellcheck (requires shellcheck installed)
make check-perms # verify install.sh, doctor.sh, bin/zl are executable
```

There is no interactive test harness yet. If you add one, you become its
maintainer. The CI workflow runs `make test` on every push and PR.

---

## Commit messages

Follow the conventional commits format:

```
type(scope): short description

Optional longer explanation. Wrap at 72 characters.

Refs: #123
```

**Types:** `fix`, `feat`, `docs`, `chore`, `refactor`, `test`, `ci`

**Scope:** `core`, `plugin/git`, `plugin/docker`, `install`, `doctor`, `cli`, `docs`

**Examples:**

```
fix(core/plugin_manager): move local fname before loop to prevent zsh output
feat(plugin/docker): add dkip command for container IP listing
docs(README): add benchmark comparison table
chore(ci): add shellcheck to lint workflow
```

Breaking changes append `!` after the type: `fix(core)!: change plugin lifecycle order`

---

## Code of conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

The short version: be direct and respectful. Disagreement about technical
decisions is healthy. Personal attacks are not tolerated.

Maintainers have final say on what goes into the codebase. A "no" on a PR is
not a rejection of the person — it means the change doesn't fit the project's
scope right now.

---

*Questions that don't fit an issue? Open a [GitHub Discussion](https://github.com/zerolinux-os/zero_terminal/discussions).*
