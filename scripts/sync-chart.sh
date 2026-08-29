#!/usr/bin/env bash
#
# Sync a vendored Helm chart from its upstream git source.
#
# Each vendored chart carries a small `.upstream` file next to its Chart.yaml:
#
#   UPSTREAM_REPO=https://github.com/volcengine/OpenViking.git
#   UPSTREAM_PATH=deploy/helm/openviking
#   UPSTREAM_REF=main
#   UPSTREAM_SHA=<commit pinned by the last sync>
#
# The script does a shallow + blobless + sparse clone of the upstream repo, so it
# only ever downloads the chart's own blobs (not the whole upstream monorepo),
# copies them into the chart dir, and records the new upstream commit in
# UPSTREAM_SHA. Files we manage locally (`.helmignore`, `.upstream`) are never
# overwritten. Files that exist locally but not upstream are reported and left in
# place, so your customizations survive and upstream deletions stay visible.
#
# Usage:
#   scripts/sync-chart.sh <name>          apply upstream changes to charts/<name>
#   scripts/sync-chart.sh --check <name>  report upstream state only, change nothing
#   REF=<tag-or-branch> scripts/sync-chart.sh <name>  sync to a specific ref (and pin it)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHARTS_DIR="$REPO_ROOT/charts"

mode="sync"
name=""
if [[ "${1:-}" == "--check" ]]; then
  mode="check"
  name="${2:-}"
else
  name="${1:-}"
fi

if [[ -z "$name" ]]; then
  echo "usage: sync-chart.sh [--check] <chart-name>" >&2
  exit 1
fi

chart_dir="$CHARTS_DIR/$name"
upstream_file="$chart_dir/.upstream"
if [[ ! -f "$upstream_file" ]]; then
  echo "error: no .upstream file at $upstream_file (is '$name' a vendored chart?)" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$upstream_file"
UPSTREAM_REPO="${UPSTREAM_REPO:?missing UPSTREAM_REPO in $upstream_file}"
UPSTREAM_PATH="${UPSTREAM_PATH:?missing UPSTREAM_PATH in $upstream_file}"
UPSTREAM_REF="${REF:-${UPSTREAM_REF:-main}}"

echo "==> [$name] upstream: $UPSTREAM_REPO @ $UPSTREAM_REF ($UPSTREAM_PATH)"
echo "    currently pinned at: ${UPSTREAM_SHA:-<none>}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Shallow + blobless + sparse clone: downloads only the chart's blobs.
git clone --quiet --depth 1 --single-branch --branch "$UPSTREAM_REF" \
  --filter=blob:none --sparse "$UPSTREAM_REPO" "$tmp/src"
git -C "$tmp/src" sparse-checkout set "$UPSTREAM_PATH"

if [[ ! -d "$tmp/src/$UPSTREAM_PATH" ]]; then
  echo "error: '$UPSTREAM_PATH' does not exist upstream @ $UPSTREAM_REF — did it move?" >&2
  exit 1
fi

sha="$(git -C "$tmp/src" rev-parse HEAD)"
subject="$(git -C "$tmp/src" log -1 --format=%s)"

if [[ "$mode" == "check" ]]; then
  if [[ "$sha" == "${UPSTREAM_SHA:-}" ]]; then
    echo "    up to date ($sha)"
  else
    echo "    update available: $sha  ($subject)"
    echo "    run: make sync-$name"
  fi
  exit 0
fi

if [[ "$sha" == "${UPSTREAM_SHA:-}" ]]; then
  echo "    already up to date ($sha)"
  exit 0
fi

# Copy upstream files over, keeping files we manage locally (.helmignore, .upstream).
(
  cd "$tmp/src/$UPSTREAM_PATH"
  find . -type f -not -path './.helmignore' -print0 |
    while IFS= read -r -d '' f; do
      mkdir -p "$chart_dir/$(dirname "$f")"
      cp -p "$f" "$chart_dir/$f"
    done
)

# Report files present locally but not upstream (your customizations / upstream deletions).
while IFS= read -r -d '' f; do
  rel="${f#./}"
  [[ "$rel" == ".upstream" || "$rel" == ".helmignore" ]] && continue
  if [[ ! -f "$tmp/src/$UPSTREAM_PATH/$rel" ]]; then
    echo "    kept (not in upstream): charts/$name/$rel"
  fi
done < <(cd "$chart_dir" && find . -type f -print0)

# Record the new upstream ref/sha so the next sync diffs against it.
sed -i.bak \
  -e "s|^UPSTREAM_REF=.*|UPSTREAM_REF=$UPSTREAM_REF|" \
  -e "s|^UPSTREAM_SHA=.*|UPSTREAM_SHA=$sha|" "$upstream_file"
rm -f "$upstream_file.bak"

echo "    synced to $sha  ($subject)"
if command -v helm >/dev/null 2>&1; then
  helm lint "$chart_dir" >/dev/null && echo "    helm lint: ok"
fi
echo "    review with: git diff --stat charts/$name"
