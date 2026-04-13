# =============================================================================
# ZeroLinux Terminal Framework v2 — Makefile
# =============================================================================

VERSION     := $(shell cat VERSION 2>/dev/null || echo "2.0.0")
ZL_HOME     ?= $(HOME)/.zerolinux
INSTALL_SH  := bash install.sh
PKG_NAME    := zerolinux-v$(VERSION)
PKG_FILE    := $(PKG_NAME).tar.gz

.DEFAULT_GOAL := help

# ── Formatting ────────────────────────────────────────────────────────────────
BLUE  := \033[1;34m
RESET := \033[0m
BOLD  := \033[1m

.PHONY: help install uninstall doctor package lint clean test version

help: ## Show available targets
	@printf "\n$(BLUE)$(BOLD)ZeroLinux Terminal Framework v$(VERSION)$(RESET)\n\n"
	@printf "  $(BOLD)Usage:$(RESET) make <target>\n\n"
	@awk 'BEGIN{FS=":.*##"} /^[a-zA-Z_-]+:.*##/{printf "  \033[1;33m%-16s\033[0m %s\n",$$1,$$2}' $(MAKEFILE_LIST)
	@printf "\n"

install: ## Install ZeroLinux to $$ZL_HOME (default: ~/.zerolinux)
	@printf "$(BLUE)Installing ZeroLinux v$(VERSION)...$(RESET)\n"
	@ZL_HOME=$(ZL_HOME) $(INSTALL_SH)

install-yes: ## Install without prompts (non-interactive)
	@printf "$(BLUE)Installing ZeroLinux v$(VERSION) [non-interactive]...$(RESET)\n"
	@ZL_HOME=$(ZL_HOME) $(INSTALL_SH) --yes

install-dry: ## Dry run — show what install would do
	@$(INSTALL_SH) --dry-run

uninstall: ## Uninstall ZeroLinux (keeps backup)
	@printf "$(BLUE)Uninstalling ZeroLinux...$(RESET)\n"
	@bash uninstall.sh

doctor: ## Run system health diagnostics
	@bash doctor.sh

package: clean-pkg ## Build distributable tarball
	@printf "$(BLUE)Packaging $(PKG_NAME)...$(RESET)\n"
	@mkdir -p dist
	@tar -czf dist/$(PKG_FILE) \
		--exclude='.git' \
		--exclude='dist' \
		--exclude='*.bak' \
		--exclude='*.log' \
		--transform "s|^\.|$(PKG_NAME)|" \
		.
	@printf "  \033[0;32m✓\033[0m  dist/$(PKG_FILE)  $$(du -sh dist/$(PKG_FILE) | cut -f1)\n"
	@sha256sum dist/$(PKG_FILE) | tee dist/$(PKG_NAME).sha256

lint: ## Lint all shell scripts (requires shellcheck)
	@which shellcheck > /dev/null 2>&1 || { printf "  \033[1;33m!\033[0m  shellcheck not found — install: pacman -S shellcheck\n"; exit 0; }
	@printf "$(BLUE)Running shellcheck...$(RESET)\n"
	@errors=0; \
	for f in install.sh uninstall.sh doctor.sh bin/zl; do \
		if shellcheck -S warning "$$f" 2>/dev/null; then \
			printf "  \033[0;32m✓\033[0m  $$f\n"; \
		else \
			printf "  \033[1;31m✗\033[0m  $$f\n"; \
			errors=$$((errors+1)); \
		fi; \
	done; \
	[ $$errors -eq 0 ] || exit 1

test: ## Run basic self-tests
	@printf "$(BLUE)Running self-tests...$(RESET)\n"
	@bash -n install.sh   && printf "  \033[0;32m✓\033[0m  install.sh syntax OK\n"   || printf "  \033[1;31m✗\033[0m  install.sh syntax FAIL\n"
	@bash -n uninstall.sh && printf "  \033[0;32m✓\033[0m  uninstall.sh syntax OK\n" || printf "  \033[1;31m✗\033[0m  uninstall.sh syntax FAIL\n"
	@bash -n doctor.sh    && printf "  \033[0;32m✓\033[0m  doctor.sh syntax OK\n"    || printf "  \033[1;31m✗\033[0m  doctor.sh syntax FAIL\n"
	@bash -n bin/zl       && printf "  \033[0;32m✓\033[0m  bin/zl syntax OK\n"       || printf "  \033[1;31m✗\033[0m  bin/zl syntax FAIL\n"
	@for p in plugins/*/init.zsh plugins/*/commands.zsh; do \
		[ -f "$$p" ] || continue; \
		bash -n "$$p" && printf "  \033[0;32m✓\033[0m  $$p syntax OK\n" || printf "  \033[1;31m✗\033[0m  $$p syntax FAIL\n"; \
	done
	@printf "  \033[0;32m✓\033[0m  All syntax checks passed\n"

check-perms: ## Verify file permissions
	@printf "$(BLUE)Checking permissions...$(RESET)\n"
	@for f in install.sh uninstall.sh doctor.sh bin/zl; do \
		[ -x "$$f" ] && printf "  \033[0;32m✓\033[0m  $$f [executable]\n" \
		             || printf "  \033[1;33m!\033[0m  $$f [not executable] — fixing\n" && chmod +x "$$f"; \
	done

fix-perms: ## Fix all file permissions
	@chmod +x install.sh uninstall.sh doctor.sh bin/zl
	@chmod 644 core/*.zsh config/*.zsh plugins/*/*.zsh plugins/*/*.zl
	@chmod 644 VERSION LICENSE CHANGELOG.md
	@printf "  \033[0;32m✓\033[0m  Permissions fixed\n"

version: ## Show version
	@printf "ZeroLinux Terminal Framework v$(VERSION)\n"

clean-pkg: ## Remove dist directory
	@rm -rf dist/

clean: clean-pkg ## Clean build artifacts
	@find . -name "*.bak.*" -newer VERSION -delete 2>/dev/null || true
	@printf "  \033[0;32m✓\033[0m  Clean complete\n"
