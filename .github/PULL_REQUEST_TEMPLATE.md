## Summary

<!-- One or two sentences: what does this PR change and why? -->

Fixes #<!-- issue number, if applicable -->

---

## Type of change

- [ ] Bug fix (non-breaking)
- [ ] New plugin
- [ ] New feature (non-breaking)
- [ ] Breaking change (changes existing behavior)
- [ ] Documentation only
- [ ] CI / tooling

---

## What was changed

<!-- List the specific files and what was done in each. Be concrete. -->

| File | Change |
|------|--------|
| | |

---

## How to test this

<!-- Step-by-step instructions to reproduce and verify the fix/feature. -->

```bash
# Paste the commands a reviewer needs to run
```

Expected output:

```
# Paste the expected result
```

---

## Checklist

- [ ] `make test` passes (all syntax checks green)
- [ ] `make lint` passes or deviations are explained below
- [ ] No new stdout output during shell startup (default `ZL_LOG_LEVEL=1`)
- [ ] New functions use the correct namespace (`zl::*` for core, `zl_plugin_*` for plugins)
- [ ] New variables are `local` or `typeset` (no global leaks)
- [ ] If this is a plugin: `ZL_STRICT_SAFETY=1` scan passes cleanly
- [ ] If this changes the plugin lifecycle: the four-step order is preserved
- [ ] CHANGELOG.md updated under `[Unreleased]`

---

## Notes for reviewer

<!-- Anything that needs explanation: trade-offs made, alternatives considered,
     follow-up work planned. Leave blank if self-explanatory. -->
