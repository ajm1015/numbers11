# Bash dev environment — lint, format, test
SHELL := /bin/bash
DIRS   := scripts lib bin examples templates
BATS   ?= bats

.PHONY: lint format test install-deps all

lint:
	@command -v shellcheck >/dev/null 2>&1 || { echo "Install shellcheck: brew install shellcheck"; exit 1; }
	@find $(DIRS) -name '*.sh' -exec shellcheck {} + 2>/dev/null || true

format:
	@command -v shfmt >/dev/null 2>&1 || { echo "Install shfmt: brew install shfmt"; exit 1; }
	@find $(DIRS) -name '*.sh' -exec shfmt -w -i 2 -ci {} + 2>/dev/null || true

test:
	@command -v $(BATS) >/dev/null 2>&1 || { echo "Install bats: brew install bats-core"; exit 1; }
	@$(BATS) tests/

install-deps:
	brew install shellcheck shfmt bats-core

all: lint format test
