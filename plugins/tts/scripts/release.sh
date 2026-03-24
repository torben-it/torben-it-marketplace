#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PLUGIN_JSON="$ROOT/.claude-plugin/plugin.json"
PYPROJECT="$ROOT/pyproject.toml"
CHANGELOG="$ROOT/CHANGELOG.md"

# --- Usage ---
usage() {
    echo "Usage: $(basename "$0") [patch|minor|major]"
    exit 1
}

[[ $# -lt 1 ]] && usage

BUMP_TYPE="$1"
[[ "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]] || usage

# --- Read current version from plugin.json ---
CURRENT=$(grep -oP '"version":\s*"\K[0-9]+\.[0-9]+\.[0-9]+' "$PLUGIN_JSON")
if [[ -z "$CURRENT" ]]; then
    echo "error: could not read version from $PLUGIN_JSON" >&2
    exit 1
fi

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

# --- Bump ---
case "$BUMP_TYPE" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac

NEW="${MAJOR}.${MINOR}.${PATCH}"
TODAY=$(date +%Y-%m-%d)

echo "Bumping $CURRENT → $NEW ($BUMP_TYPE)"

# --- Update plugin.json ---
sed -i "s/\"version\": \"$CURRENT\"/\"version\": \"$NEW\"/" "$PLUGIN_JSON"

# --- Update pyproject.toml ---
sed -i "s/^version = \"$CURRENT\"/version = \"$NEW\"/" "$PYPROJECT"

# --- Generate changelog entry via AI ---
echo "Generating changelog from git history..."

# Find the last tag to diff against
LAST_TAG=$(git -C "$ROOT" describe --tags --abbrev=0 2>/dev/null || echo "")

if [[ -n "$LAST_TAG" ]]; then
    DIFF_RANGE="${LAST_TAG}..HEAD"
    GIT_LOG=$(git -C "$ROOT" log --oneline "$DIFF_RANGE" -- .)
    GIT_DIFF=$(git -C "$ROOT" diff "$DIFF_RANGE" -- . ':!*.lock')
else
    GIT_LOG=$(git -C "$ROOT" log --oneline -- .)
    GIT_DIFF=$(git -C "$ROOT" diff HEAD -- . ':!*.lock')
fi

# Also include any uncommitted changes (staged + unstaged)
UNCOMMITTED=$(git -C "$ROOT" diff HEAD -- . ':!*.lock' 2>/dev/null || true)

PROMPT="You are writing a CHANGELOG entry for version $NEW of a Claude Code TTS plugin.

The format MUST follow Keep a Changelog (https://keepachangelog.com/en/1.1.0/).
Output ONLY the entry body — no version header, no markdown fences, no preamble.
Use the categories: ### Added, ### Changed, ### Fixed, ### Removed — but ONLY include categories that have entries.
Each bullet should be concise (one line). Write in English.

Previous version: $CURRENT
Bump type: $BUMP_TYPE

Git log since last release:
$GIT_LOG

Diff since last release (truncated):
${GIT_DIFF:0:8000}

Uncommitted changes:
${UNCOMMITTED:0:4000}"

CHANGELOG_BODY=$(echo "$PROMPT" | claude --print 2>/dev/null)

if [[ -z "$CHANGELOG_BODY" ]]; then
    echo "error: claude CLI failed to generate changelog. Is it installed?" >&2
    echo "Falling back to empty template."
    CHANGELOG_BODY="### Added

### Changed

### Fixed"
fi

echo ""
echo "── Generated changelog ──"
echo "$CHANGELOG_BODY"
echo "─────────────────────────"
echo ""

# Ask for confirmation
read -rp "Accept this changelog? [Y/n/e(dit)] " REPLY
case "${REPLY:-Y}" in
    [nN])
        echo "Aborted. Version files already bumped — revert with: git checkout $PLUGIN_JSON $PYPROJECT"
        exit 1
        ;;
    [eE])
        TMPFILE=$(mktemp /tmp/changelog-entry.XXXXXX.md)
        echo "$CHANGELOG_BODY" > "$TMPFILE"
        "${EDITOR:-vi}" "$TMPFILE"
        CHANGELOG_BODY=$(cat "$TMPFILE")
        rm -f "$TMPFILE"
        ;;
esac

# --- Insert into CHANGELOG.md ---
HEADER="## [$NEW] - $TODAY"

# Build the full entry block
ENTRY="$HEADER

$CHANGELOG_BODY"

# Create temp file with new entry inserted after the semver preamble
{
    sed -n '1,/adheres to \[Semantic Versioning\]/p' "$CHANGELOG"
    echo ""
    echo "$ENTRY"
    sed '1,/adheres to \[Semantic Versioning\]/d' "$CHANGELOG"
} > "${CHANGELOG}.tmp"

mv "${CHANGELOG}.tmp" "$CHANGELOG"

# --- Commit & tag ---
cd "$ROOT"
git add "$PLUGIN_JSON" "$PYPROJECT" "$CHANGELOG"
git commit -m "release v$NEW"
git tag "v$NEW"

echo ""
echo "Done: v$NEW committed and tagged."
echo "Push med: git push && git push --tags"
