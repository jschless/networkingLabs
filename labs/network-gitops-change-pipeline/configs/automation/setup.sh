#!/usr/bin/env bash
set -euo pipefail

LAB_REPO="${LAB_REPO:-/workspace/lab-repo}"
if [[ "$LAB_REPO" != "/workspace/lab-repo" ]]; then
  echo "Refusing unsafe LAB_REPO: $LAB_REPO" >&2
  exit 2
fi
rm -rf "$LAB_REPO"
mkdir -p "$LAB_REPO"
cp -R /opt/gitops-seed/. "$LAB_REPO/"
cd "$LAB_REPO"
git init -b main >/dev/null
git config user.name "Network GitOps Lab"
git config user.email "gitops-lab@example.invalid"
git add .
git commit -m "baseline: identified network intent" >/dev/null
git rev-parse HEAD > .initial-commit
printf '.initial-commit\n' >> .git/info/exclude
mkdir -p evidence rendered
chmod 700 evidence
