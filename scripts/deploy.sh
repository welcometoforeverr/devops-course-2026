#!/usr/bin/env bash
set -euo pipefail
fail() { printf '%s\n' "$*" >&2; exit 1; }
dry=()
if (( $# > 1 )); then fail 'Usage: deploy.sh [--dry-run]'; fi
if (( $# == 1 )); then
  [[ "$1" == '--dry-run' ]] || fail 'Usage: deploy.sh [--dry-run]'
  dry=(--dry-run)
fi
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
root=$(git -C "$script_dir" rev-parse --show-toplevel) || fail 'Not a Git repository'
if command -v cygpath >/dev/null 2>&1 && [[ "$root" =~ ^[A-Za-z]: ]]; then
  root=$(cygpath -u "$root")
fi
[[ -f "$root/site/index.html" ]] || fail 'Missing site/index.html; deployment cancelled'
[[ -z "$(git -C "$root" status --porcelain --untracked-files=all)" ]] || fail 'Uncommitted changes; deployment cancelled'
remote="${DEPLOY_REMOTE:-devops}"
remote_dir="${DEPLOY_REMOTE_DIR:-/var/www/devops-site}"
site_url="${DEPLOY_SITE_URL:-https://devops.local}"
ca="${DEPLOY_CA_CERT:-$HOME/devops.crt}"
rsync -avz --delete --chmod=D755,F644 "${dry[@]}" \
  -e 'ssh -o BatchMode=yes -o ConnectTimeout=5' \
  "$root/site/" "$remote:$remote_dir/" || fail 'rsync failed'
if (( ${#dry[@]} )); then printf 'Dry run complete\n'; exit 0; fi
curl --silent --show-error --fail --connect-timeout 5 --max-time 15 \
  --cacert "$ca" "$site_url" >/dev/null || fail 'HTTPS verification failed'
printf 'Deployed commit %s\n' "$(git -C "$root" rev-parse --short HEAD)"
