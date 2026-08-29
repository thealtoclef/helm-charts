# Chart sync tooling.
#
# Any chart that vendors files from an upstream source gets a `.upstream` file
# (see charts/openviking/.upstream for the format). The targets below auto-discover
# those files, so adding a new vendored chart is just: create charts/<name> + a
# `.upstream` file. No Makefile edits needed.

SHELL := /bin/bash
REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
CHARTS_DIR := $(REPO_ROOT)/charts
UPSTREAM_FILES := $(wildcard $(CHARTS_DIR)/*/.upstream)
VENDORED_CHARTS := $(patsubst $(CHARTS_DIR)/%/.upstream,%,$(UPSTREAM_FILES))
SYNC_SCRIPT := $(REPO_ROOT)/scripts/sync-chart.sh

.PHONY: help charts sync check

help: ## Show available targets
	@echo "Usage:"
	@echo "  make charts              list charts tracked for upstream sync"
	@echo "  make sync                update all vendored charts from upstream"
	@echo "  make sync-<name>         update one chart, e.g. make sync-openviking"
	@echo "  make check               report upstream state without applying changes"

charts: ## List charts tracked for upstream sync
	@if [ -z "$(VENDORED_CHARTS)" ]; then \
	  echo "No vendored charts (no charts/*/.upstream files)."; \
	else \
	  echo "Vendored charts:"; \
	  for c in $(VENDORED_CHARTS); do echo "  - $$c"; done; \
	fi

sync: ## Update all vendored charts from upstream
	@if [ -z "$(VENDORED_CHARTS)" ]; then echo "Nothing to sync."; exit 0; fi
	@for c in $(VENDORED_CHARTS); do echo; echo "==> syncing $$c"; $(SYNC_SCRIPT) "$$c"; done

sync-%: ## Update one chart from upstream (e.g. make sync-openviking)
	@$(SYNC_SCRIPT) "$*"

check: ## Report upstream state without applying changes
	@for c in $(VENDORED_CHARTS); do $(SYNC_SCRIPT) --check "$$c"; done
