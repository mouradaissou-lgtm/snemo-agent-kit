#!/usr/bin/env bash
# push.sh — one-command publish for snemo-agent-kit
#
# Usage:   ./push.sh "commit message"
#          ./push.sh                (auto message: "Update kit <date>")
#
# Auth: PAT lives in the macOS Keychain (git credential.helper osxkeychain).
#       No token in the remote URL, no token in any file.
#       If auth ever fails (403/404), the PAT expired or was revoked:
#       regenerate at https://github.com/settings/tokens then re-store:
#         printf 'protocol=https\nhost=github.com\nusername=mouradaissou-lgtm\npassword=<NEW_PAT>\n' \
#           | git credential-osxkeychain store
set -euo pipefail
cd "$(dirname "$0")"

msg="${1:-Update kit $(date '+%Y-%m-%d %H:%M')}"

# 1. sanity: never push a tracked real token
if git grep -IE 'ghp_[A-Za-z0-9]{36}' -- . 2>/dev/null | grep -qvE 'deny-list|denylist|example|placeholder|<NEW_PAT>'; then
  echo "REFUSING: a ghp_ token pattern is tracked. Check: git grep -IE 'ghp_[A-Za-z0-9]{36}'"
  git grep -IE 'ghp_[A-Za-z0-9]{36}' -- . || true
  exit 1
fi

# 2. stage + commit
git add -A
if git diff --cached --quiet; then
  echo "Nothing new to commit."
else
  git commit -m "$msg"
fi

# 3. push
git push

echo
echo "Pushed:  $(git log --oneline -1)"
echo "Remote:  $(git remote get-url origin)"
echo "GitHub:  https://github.com/mouradaissou-lgtm/snemo-agent-kit"
