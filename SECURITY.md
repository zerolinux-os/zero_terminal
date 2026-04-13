# Security Policy

## Supported versions

Only the latest release receives security fixes.

| Version | Supported |
|---------|-----------|
| 2.1.x   | ✅ Yes    |
| < 2.0   | ✗ No     |

---

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Report security issues by emailing **zarchblack@protonmail.com** with:

1. A clear description of the vulnerability
2. Steps to reproduce (minimal example preferred)
3. The potential impact
4. Your suggested fix, if you have one

You will receive an acknowledgement within **48 hours** and a status update
within **7 days**. If the issue is confirmed, a fix will be prepared and
released before public disclosure.

We follow responsible disclosure: we ask for a **90-day window** to fix and
release before you publish details publicly. We will credit you in the release
notes unless you prefer to remain anonymous.

---

## Security model and scope

### In scope

The following are considered security vulnerabilities if they can be triggered
by a third-party plugin or malformed configuration:

- Shell command injection through plugin loading
- Escape from plugin isolation (a plugin corrupting another plugin's state)
- Bypass of the safety scanner (`ZL_STRICT_SAFETY=1`)
- Privilege escalation through any ZeroLinux code path
- Arbitrary file write or read outside `ZL_HOME` during install or load

### Out of scope

These are not vulnerabilities in ZeroLinux:

- A plugin that the **user deliberately installed** doing something harmful.
  ZeroLinux scans plugins but is not a sandbox. If you install a malicious
  plugin and disable `ZL_STRICT_SAFETY`, that is user choice.
- Security issues in third-party tools (fzf, bat, eza, etc.) that ZeroLinux
  uses as optional dependencies
- Findings from automated scanners with no proof of exploitability
- Social engineering the maintainers

---

## Plugin security scanner

ZeroLinux scans every plugin before loading, checking for:

| Pattern | What it detects |
|---------|----------------|
| `alias (rm\|sudo\|cd\|…) =` | System command alias override |
| `function (rm\|sudo\|cd\|…)` | System command function redefinition |
| `curl … \| sh` | Remote code execution |
| `eval "$variable"` | Unsafe eval with user-controlled input |

Enable strict mode to **block** rather than warn:

```bash
ZL_STRICT_SAFETY=1 zsh
```

Add to `~/.zerolinuxrc` to make it permanent:

```zsh
ZL_STRICT_SAFETY=1
```

---

## Verifying releases

Every release publishes a SHA-256 checksum alongside the tarball.

```bash
# Download
curl -LO https://github.com/zerolinux-os/zero_terminal/releases/latest/download/zerolinux-v2.1.1.tar.gz
curl -LO https://github.com/zerolinux-os/zero_terminal/releases/latest/download/zerolinux-v2.1.1.sha256

# Verify
sha256sum -c zerolinux-v2.1.1.sha256
```

Expected output: `zerolinux-v2.1.1.tar.gz: OK`

Do not install from untrusted mirrors or forks without verifying the checksum.
