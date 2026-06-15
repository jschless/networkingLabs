#!/usr/bin/env bash
# Lint docs/ for malformed admonitions.
#
# MkDocs admonitions (!!! / ???) require the body on the NEXT line, indented
# 4 spaces. When body text is left on the title line, e.g.
#
#     !!! note "Image" frr-lab:local — docker build ...
#
# the block does NOT render as an admonition box — it silently degrades to a
# plain paragraph, and `mkdocs build --strict` does not flag it. This catches
# that regression. The correct form is:
#
#     !!! note "Image"
#         frr-lab:local — docker build ...
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="$REPO_ROOT/docs"

# Match a line starting with !!! / ??? / ???+ that has a quoted "Title"
# followed by trailing non-whitespace content on the same line.
pattern='^[[:space:]]*[!?]{3}\+?[[:space:]]+[a-z]+[[:space:]]+"[^"]*"[[:space:]]*[^[:space:]]'

status=0
while IFS= read -r hit; do
    echo "FAIL $hit"
    echo "     body text must move to the next line, indented 4 spaces"
    status=1
done < <(grep -rnE "$pattern" "$DOCS_DIR" --include='*.md' || true)

if [[ $status -eq 0 ]]; then
    echo "OK: no malformed admonitions in docs/"
else
    echo ""
    echo "Malformed admonitions found. Fix by splitting the title and body:"
    echo '  !!! note "Title"'
    echo '      body text here'
fi

exit $status
