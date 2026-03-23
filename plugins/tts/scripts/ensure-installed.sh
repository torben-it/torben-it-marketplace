#!/usr/bin/env bash
set -euo pipefail

if ! command -v uv &>/dev/null; then
    echo "tts: uv not found, skipping install" >&2
    exit 0  # exit 0 so the session is not blocked
fi

diff -q "${CLAUDE_PLUGIN_ROOT}/pyproject.toml" \
        "${CLAUDE_PLUGIN_DATA}/pyproject.toml" >/dev/null 2>&1 && exit 0

cp "${CLAUDE_PLUGIN_ROOT}/pyproject.toml" "${CLAUDE_PLUGIN_DATA}/"
uv tool install --upgrade "${CLAUDE_PLUGIN_ROOT}" \
    || rm -f "${CLAUDE_PLUGIN_DATA}/pyproject.toml"