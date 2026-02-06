#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]:-$0}")"

if [ ! -e AGENTS.md ]; then
	echo "AGENTS.md not found in $(pwd)." >&2
	exit 1
fi

ln -sf AGENTS.md GEMINI.md
ln -sf AGENTS.md CLAUDE.md