#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
version=${1:?Usage: release-notes.sh VERSION}
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    printf 'Error: invalid release version: %s\n' "$version" >&2
    exit 2
}
version_regex=${version//./\\.}
awk -v heading="^##[[:space:]]+${version_regex}([[:space:]]|$)" '
    $0 ~ heading { found=1; next }
    found && /^##[[:space:]]/ { exit }
    found { print }
    END { if (!found) exit 1 }
' "$repo_root/CHANGELOG.md"
