SHELL := /bin/bash
.DEFAULT_GOAL := help

APP_NAME := Free
SWIFT := swift

.PHONY: help build test test-verbose coverage logic-gate ui-gate regression-tests coverage-gates app dmg package run clean deep-clean hooks

help:
	@echo "Available targets:"
	@echo "  make build         - Build Swift package in debug mode"
	@echo "  make test          - Run test suite"
	@echo "  make test-verbose  - Run test suite with verbose output"
	@echo "  make coverage      - Run tests with code coverage and print summary"
	@echo "  make logic-gate    - Enforce logic/services regional coverage gate (default 98.0%)"
	@echo "  make ui-gate       - Enforce UI/* regional coverage threshold (default 85.0%)"
	@echo "  make regression-tests - Run targeted fragile-UI regression suites"
	@echo "  make coverage-gates - Run coverage + logic/ui gates"
	@echo "  make app           - Build macOS .app bundle via build.sh"
	@echo "  make dmg           - Build release .dmg via package.sh"
	@echo "  make package       - Alias for dmg"
	@echo "  make run           - Launch Free.app"
	@echo "  make clean         - Clean package artifacts and generated app bundle"
	@echo "  make deep-clean    - Remove all generated artifacts including dmg"
	@echo "  make hooks         - Install git hooks from scripts/githooks"

build:
	@$(SWIFT) build

test:
	@$(SWIFT) test --no-parallel

test-verbose:
	@$(SWIFT) test --no-parallel -v

coverage:
	@rm -rf .build/coverage-home .build/coverage-main .build/coverage-merged
	@mkdir -p .build/coverage-home .build/coverage-merged
	@HOME=$$PWD/.build/coverage-home \
	XDG_CONFIG_HOME=$$PWD/.build/coverage-home \
	FREE_COVERAGE_MODE=1 \
		$(SWIFT) test --enable-code-coverage --no-parallel \
		--scratch-path .build/coverage-main
	@profraw_count=$$(find .build/coverage-main -name "*.profraw" | wc -l | tr -d ' '); \
	bin=$$(find .build/coverage-main -path "*/debug/FreePackageTests.xctest/Contents/MacOS/FreePackageTests" -not -path "*.dSYM/*" | head -n 1); \
	src_files=$$(find Sources -type f -name "*.swift" | sort); \
	if [[ "$$profraw_count" == "0" || -z "$$bin" ]]; then \
		echo "Could not locate coverage artifacts."; \
		exit 1; \
	fi; \
	if [[ -z "$$src_files" ]]; then \
		echo "Could not locate source files for coverage report."; \
		exit 1; \
	fi; \
	find .build/coverage-main -name "*.profraw" -print0 \
		| xargs -0 xcrun llvm-profdata merge -sparse -o .build/coverage-merged/merged.profdata; \
	xcrun llvm-cov report "$$bin" -instr-profile=.build/coverage-merged/merged.profdata $$src_files

LOGIC_REGION_GATE ?= 98.0
LOGIC_REGION_PATTERN ?= ^Logic/State/Services/
UI_REGION_GATE ?= 85.0

logic-gate:
	@bin=$$(find .build/coverage-main -path "*/debug/FreePackageTests.xctest/Contents/MacOS/FreePackageTests" -not -path "*.dSYM/*" | head -n 1); \
	src_files=$$(find Sources -type f -name "*.swift" | sort); \
	if [[ -z "$$bin" || ! -f .build/coverage-merged/merged.profdata ]]; then \
		echo "Missing coverage artifacts. Run 'make coverage' first."; \
		exit 1; \
	fi; \
	actual=$$(xcrun llvm-cov report "$$bin" -instr-profile=.build/coverage-merged/merged.profdata $$src_files \
		| awk -v pattern='$(LOGIC_REGION_PATTERN)' '$$1 ~ pattern { total += $$2; missed += $$3 } END { if (total == 0) print "0.00"; else printf "%.2f", ((total-missed)/total)*100 }'); \
	echo "Logic/services regional coverage: $$actual% (gate: $(LOGIC_REGION_GATE)%, pattern: $(LOGIC_REGION_PATTERN))"; \
	awk "BEGIN { exit !($$actual >= $(LOGIC_REGION_GATE)) }"

ui-gate:
	@bin=$$(find .build/coverage-main -path "*/debug/FreePackageTests.xctest/Contents/MacOS/FreePackageTests" -not -path "*.dSYM/*" | head -n 1); \
	src_files=$$(find Sources -type f -name "*.swift" | sort); \
	if [[ -z "$$bin" || ! -f .build/coverage-merged/merged.profdata ]]; then \
		echo "Missing coverage artifacts. Run 'make coverage' first."; \
		exit 1; \
	fi; \
	actual=$$(xcrun llvm-cov report "$$bin" -instr-profile=.build/coverage-merged/merged.profdata $$src_files \
		| awk '/^UI\// { total += $$2; missed += $$3 } END { if (total == 0) print "0.00"; else printf "%.2f", ((total-missed)/total)*100 }'); \
	echo "UI regional coverage: $$actual% (gate: $(UI_REGION_GATE)%)"; \
	awk "BEGIN { exit !($$actual >= $(UI_REGION_GATE)) }"

regression-tests:
	@$(SWIFT) test --no-parallel --filter FocusViewTests
	@$(SWIFT) test --no-parallel --filter WeeklyCalendarSurfaceTests
	@$(SWIFT) test --no-parallel --filter AllowedWebsitesFloatingEditorTests

coverage-gates: coverage logic-gate ui-gate

app:
	@./build.sh

dmg:
	@./package.sh
	@echo "DMG contains Free.app + Applications shortcut for manual install."

package: dmg

run:
	@open "$(APP_NAME).app"

clean:
	@$(SWIFT) package clean
	@rm -rf "$(APP_NAME).app" dist

deep-clean:
	@rm -rf .build "$(APP_NAME).app" "$(APP_NAME).dmg" dist

hooks:
	@chmod +x scripts/githooks/*
	@git config core.hooksPath scripts/githooks
	@echo "Git hooks installed (core.hooksPath -> scripts/githooks)"
