SHELL := /bin/bash
.DEFAULT_GOAL := help

APP_NAME := Free
SWIFT := swift

.PHONY: help build test test-verbose coverage app dmg package run clean deep-clean

help:
	@echo "Available targets:"
	@echo "  make build         - Build Swift package in debug mode"
	@echo "  make test          - Run test suite"
	@echo "  make test-verbose  - Run test suite with verbose output"
	@echo "  make coverage      - Run tests with code coverage and print summary"
	@echo "  make app           - Build macOS .app bundle via build.sh"
	@echo "  make dmg           - Build release .dmg via package.sh"
	@echo "  make package       - Alias for dmg"
	@echo "  make run           - Launch Free.app"
	@echo "  make clean         - Clean package artifacts and generated app bundle"
	@echo "  make deep-clean    - Remove all generated artifacts including dmg"

build:
	@$(SWIFT) build

test:
	@$(SWIFT) test

test-verbose:
	@$(SWIFT) test -v

coverage:
	@$(SWIFT) test --enable-code-coverage
	@profdata=$$(find .build -path "*/debug/codecov/default.profdata" | head -n 1); \
	bin=$$(find .build -path "*/debug/FreePackageTests.xctest/Contents/MacOS/FreePackageTests" -not -path "*.dSYM/*" | head -n 1); \
	src_files=$$(find Sources -type f -name "*.swift" | sort); \
	if [[ -z "$$profdata" || -z "$$bin" ]]; then \
		echo "Could not locate coverage artifacts."; \
		exit 1; \
	fi; \
	if [[ -z "$$src_files" ]]; then \
		echo "Could not locate source files for coverage report."; \
		exit 1; \
	fi; \
	xcrun llvm-cov report "$$bin" -instr-profile="$$profdata" $$src_files

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
