#!/usr/bin/env bash
#
# Deploy the OST news articles from a git checkout into the landing page's
# news_articles/ directory.
#
# This script runs ON THE SERVER, from a checkout that lives OUTSIDE the web
# root. The payload is built with `git archive`, so only committed files can
# ever be published and no .git/ directory ends up in the web root.
#
# Images are NOT handled here: images/ is excluded from git (too large) and is
# synced separately from a developer machine. The --delete below never touches
# it, because rsync does not delete excluded paths.
#
# Usage:
#   ./scripts/deploy.sh                 # dry run (default)
#   ./scripts/deploy.sh --apply
#
# Options:
#   --apply          Perform the deployment. Without it, rsync runs with -n.
#   --webroot DIR    Landing page web root (default: /mnt/data/www).
#   --ref REF        Deploy this git ref instead of the updated branch.
#   --no-pull        Skip `git fetch` / fast-forward; deploy the current HEAD.
#   -h, --help       Show this help.

set -euo pipefail

WEBROOT="/mnt/data/www"
APPLY=0
DO_PULL=1
REF=""

TARGET_SUBDIR="news_articles"

# Files that are tracked in git but must never reach the web root.
PRUNE=(
  "README.md"
  "TODO.md"
  "LICENSE"
  ".gitignore"
  "docs"
  "scripts"
  "article_template.html"
)

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*"; }

usage() { sed -n '3,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)   APPLY=1 ;;
    --webroot) WEBROOT="${2:?--webroot needs a directory}"; shift ;;
    --ref)     REF="${2:?--ref needs a git ref}"; shift ;;
    --no-pull) DO_PULL=0 ;;
    -h|--help) usage ;;
    *)         die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# ---------------------------------------------------------------------------
# Safety checks
# ---------------------------------------------------------------------------

command -v git   >/dev/null || die "git is required"
command -v rsync >/dev/null || die "rsync is required"

REPO="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git checkout"
cd "$REPO"

TARGET="$WEBROOT/$TARGET_SUBDIR"
[ -d "$WEBROOT" ] || die "web root does not exist: $WEBROOT"
[ -d "$TARGET" ]  || die "target does not exist: $TARGET"

REPO_REAL="$(cd "$REPO" && pwd -P)"
WEBROOT_REAL="$(cd "$WEBROOT" && pwd -P)"

case "$REPO_REAL/" in
  "$WEBROOT_REAL"/*)
    die "the checkout ($REPO_REAL) is inside the web root ($WEBROOT_REAL).
       Move it out (e.g. to /mnt/data/src/) before deploying."
    ;;
esac

if [ -n "$(git status --porcelain)" ]; then
  git status --short >&2
  die "working tree is not clean; commit or stash before deploying"
fi

# ---------------------------------------------------------------------------
# Update the checkout
# ---------------------------------------------------------------------------

if [ -n "$REF" ]; then
  DEPLOY_REF="$REF"
elif [ "$DO_PULL" -eq 1 ]; then
  BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  [ "$BRANCH" = "main" ] || die "on branch '$BRANCH'; deploy from 'main' or pass --ref"
  info "fetching origin"
  git fetch --quiet origin
  info "fast-forwarding $BRANCH to origin/$BRANCH"
  git merge --ff-only "origin/$BRANCH"
  DEPLOY_REF="HEAD"
else
  DEPLOY_REF="HEAD"
fi

info "deploying $(git rev-parse --short "$DEPLOY_REF") ($(git log -1 --format=%s "$DEPLOY_REF"))"

# ---------------------------------------------------------------------------
# Build the payload from git, never from the working directory
# ---------------------------------------------------------------------------

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

git archive --format=tar "$DEPLOY_REF" | tar -x -C "$STAGE"

for item in "${PRUNE[@]}"; do
  rm -rf "${STAGE:?}/$item"
done

[ -f "$STAGE/index.html" ]    || die "index.html missing from the payload"
[ -f "$STAGE/articles.json" ] || die "articles.json missing from the payload"

# ---------------------------------------------------------------------------
# Pre-flight gate 1: local references must exist
#
# images/ is skipped: it is deployed separately and is intentionally absent
# from git. Everything else (css/, js/, fonts/, favicon.ico) ships from here.
# ---------------------------------------------------------------------------

normalize_path() {
  local path="$1" part out=() IFS='/'
  for part in $path; do
    case "$part" in
      ''|'.') ;;
      '..') [ "${#out[@]}" -gt 0 ] && unset 'out[${#out[@]}-1]' ;;
      *) out+=("$part") ;;
    esac
  done
  printf '%s' "${out[*]-}"
}

info "checking local asset references"
missing=0
while IFS= read -r file; do
  dir="$(dirname "${file#"$STAGE"/}")"
  [ "$dir" = "." ] && dir=""

  while IFS= read -r ref; do
    case "$ref" in
      ''|http://*|https://*|//*|data:*|mailto:*|\#*) continue ;;
    esac
    ref="${ref%%\#*}"
    ref="${ref%%\?*}"
    [ -n "$ref" ] || continue

    if [ "${ref#/}" != "$ref" ]; then
      continue                                   # site-absolute: another deployment
    fi
    target="$(normalize_path "$dir/$ref")"

    case "$target" in
      images/*|'') continue ;;                   # deployed separately
      ../*) continue ;;                          # outside this repository
    esac

    if [ ! -e "$STAGE/$target" ]; then
      printf '  MISSING  %-40s referenced by %s\n' "$target" "${file#"$STAGE"/}" >&2
      missing=$((missing + 1))
    fi
  done < <(
    grep -ohE '(src|href)="[^"]*"' "$file" 2>/dev/null \
      | sed -E 's/^(src|href)="//; s/"$//'
    grep -ohE 'url\([^)]*\)' "$file" 2>/dev/null \
      | sed -E 's/^url\(//; s/\)$//; s/^["'"'"']//; s/["'"'"']$//'
  )
done < <(find "$STAGE" -type f \( -name '*.html' -o -name '*.css' \))

[ "$missing" -eq 0 ] || die "$missing referenced file(s) missing from the payload — nothing was deployed"

# ---------------------------------------------------------------------------
# Pre-flight gate 2: articles.json must satisfy what the landing page expects
#
# static/js/base.js on the landing page validates every entry and silently
# drops malformed ones. Checking here means a typo is caught at deploy time
# instead of quietly removing an article from the news banner.
# ---------------------------------------------------------------------------

if command -v python3 >/dev/null; then
  info "validating articles.json"
  python3 - "$STAGE" <<'PY' || die "articles.json did not validate — nothing was deployed"
import json, os, re, sys

stage = sys.argv[1]
SAFE_FILE  = re.compile(r'^[A-Za-z0-9_-]+\.html$')
SAFE_IMAGE = re.compile(r'^images/(thumbs/)?[A-Za-z0-9_.-]+\.(jpe?g|png|webp)$', re.I)
SAFE_DATE  = re.compile(r'^\d{4}-\d{2}-\d{2}$')

with open(os.path.join(stage, 'articles.json'), encoding='utf-8') as fh:
    articles = json.load(fh)

if not isinstance(articles, list):
    sys.exit('  articles.json must contain a list')

errors = 0
for i, a in enumerate(articles):
    label = f'  entry {i}'
    if not isinstance(a, dict):
        print(f'{label}: not an object'); errors += 1; continue
    label = f'  {a.get("filename", f"entry {i}")}'
    if not isinstance(a.get('title'), str) or not a['title']:
        print(f'{label}: missing or empty "title"'); errors += 1
    if not SAFE_FILE.match(str(a.get('filename', ''))):
        print(f'{label}: bad "filename"'); errors += 1
    elif not os.path.exists(os.path.join(stage, a['filename'])):
        print(f'{label}: article file not in payload'); errors += 1
    if not SAFE_DATE.match(str(a.get('publication_date', ''))):
        print(f'{label}: "publication_date" must be YYYY-MM-DD'); errors += 1
    thumb = a.get('thumbnail_path') or a.get('image_path') or ''
    if not SAFE_IMAGE.match(str(thumb)):
        print(f'{label}: bad "thumbnail_path"/"image_path"'); errors += 1

if errors:
    sys.exit(f'  {errors} problem(s) found')
print(f'  {len(articles)} article(s) OK')
PY
else
  printf 'note: python3 not available — skipping articles.json validation\n' >&2
fi

# ---------------------------------------------------------------------------
# Publish
# ---------------------------------------------------------------------------

RSYNC_OPTS=(-rlptD --chmod=D755,F644 --itemize-changes)
[ "$APPLY" -eq 1 ] || RSYNC_OPTS+=(--dry-run)

# --delete is safe here because news_articles/ belongs entirely to this repo.
# images/ is excluded and therefore protected from deletion by rsync.
info "syncing into $TARGET/"
rsync "${RSYNC_OPTS[@]}" --delete --exclude='/images/' "$STAGE/" "$TARGET/"

if [ "$APPLY" -eq 0 ]; then
  printf '\n(dry run — nothing was written; re-run with --apply)\n'
  exit 0
fi

info "done — remember to sync images/ separately if new ones were added"
