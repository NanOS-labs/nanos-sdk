#!/usr/bin/env bash
# migrate-fork.sh <manifest-name> [--dry-run]
# Assembles one NanOS-labs repo from the nanos-sdk-work workspace per ports.manifest:
#   base commit (pristine tarball or local tree, provenance in the message)
#   -> overlay commit (in-place modifications, AUDITED: prints git status before committing)
#   -> push branch 'nanos' as the org repo default.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
SDK_WORK="${SDK_WORK:-$HOME/Projects/nanos-sdk-work}"
ORG=NanOS-labs
NAME="${1:?usage: migrate-fork.sh <name> [--dry-run]}"
DRY="${2:-}"

row=$(grep -v '^#' "$HERE/ports.manifest" | awk -F'|' -v n="$NAME" '$1==n{print; exit}')
[ -n "$row" ] || { echo "no manifest row for '$NAME'"; exit 1; }
# shellcheck disable=SC2034  # LAYOUT is consumed by bootstrap.sh, not here
IFS='|' read -r _ REPO LAYOUT BASE CHECKOUT DESC <<<"$row"

WORK="$SDK_WORK/_migrate/$REPO"
rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
git init -q -b nanos

# .gitignore FIRST so build junk never enters history (sources never match these).
cat > .gitignore <<'EOF'
build/
install/
*.o
*.a
*.so
*.dylib
*.nxe
*.elf
*.ndl
*.log
.cache/
__pycache__/
*.pyc
target/
.DS_Store
EOF
git add .gitignore && git commit -qm "chore: ignore build artifacts"

# 1) base
case "$BASE" in
  tarball:*)
    TB="$SDK_WORK/${BASE#tarball:}"
    [ -f "$TB" ] || { echo "missing tarball $TB"; exit 1; }
    tar xf "$TB" --strip-components=1
    git add -A && git commit -qm "upstream base: $(basename "$TB") (pristine)

Extracted verbatim from the tarball archived in nanos-sdk-work."
    git tag upstream-base
    ;;
  tree)
    : # base IS the local tree; the overlay step below makes the single base commit
    ;;
  *) echo "unknown base kind '$BASE'"; exit 1;;
esac

# 2) overlay the live workspace tree (rsync keeps .git and .gitignore)
SRC="$SDK_WORK/$CHECKOUT"
[ -d "$SRC" ] || { echo "missing source tree $SRC"; exit 1; }
rsync -a --delete --exclude .git --exclude .gitignore "$SRC/" "$WORK/"
if [ "$NAME" = inetutils ]; then   # multi: fold the sibling services port dir in
  mkdir -p inetutils-services-port
  rsync -a --exclude .git "$SDK_WORK/inetutils-services-port/" "$WORK/inetutils-services-port/"
fi

echo "===== AUDIT: changes vs base for $NAME ====="
git add -A
git status --short | head -100
echo "===== (empty above = tree is pristine upstream) ====="

if [ "$DRY" = "--dry-run" ]; then echo "dry-run: stopping before commit/push"; exit 0; fi

if ! git diff --cached --quiet; then
  if [ "$BASE" = tree ]; then
    git commit -qm "import: $NAME workspace tree from nanos-sdk-work

Base = the live working tree (no pristine local tarball). Upstream
provenance and applied patches are documented in-repo and in
NanOS docs/ECOSYSTEM.md."
  else
    git commit -qm "nanos: in-place modifications carried from nanos-sdk-work

Everything the AUDIT block above listed vs the pristine base."
  fi
fi

# 3) create org repo + push
gh repo create "$ORG/$REPO" --public --description "$DESC" >/dev/null
git remote add origin "git@github.com:$ORG/$REPO.git"
git push -q -u origin nanos --tags
gh api -X PATCH "repos/$ORG/$REPO" -f default_branch=nanos >/dev/null
echo "DONE: https://github.com/$ORG/$REPO"
