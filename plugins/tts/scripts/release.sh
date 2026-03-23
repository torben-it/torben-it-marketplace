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

# --- Update CHANGELOG.md ---
# Insert new section after the semver preamble line
HEADER="## [$NEW] - $TODAY"
TEMPLATE="$HEADER

### Added

### Changed

### Fixed
"

# Insert after the line matching "adheres to Semantic Versioning"
sed -i "/adheres to \[Semantic Versioning\]/a\\
\\
$HEADER\\
\\
### Added\\
\\
### Changed\\
\\
### Fixed" "$CHANGELOG"

# --- Open editor for changelog ---
if [[ -n "${EDITOR:-}" ]]; then
    echo "Opening CHANGELOG.md in \$EDITOR..."
    "$EDITOR" "$CHANGELOG"
else
    echo ""
    echo "Rediger CHANGELOG.md med dine ændringer, og tryk Enter når du er klar."
    echo "  $CHANGELOG"
    read -r
fi

# --- Commit & tag ---
cd "$ROOT"
git add "$PLUGIN_JSON" "$PYPROJECT" "$CHANGELOG"
git commit -m "release v$NEW"
git tag "v$NEW"

echo ""
echo "Done: v$NEW committed and tagged."
echo "Push med: git push && git push --tags"
