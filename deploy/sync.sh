#!/usr/bin/env bash
set -euo pipefail

PVE=${PVE:-root@100.84.163.115}
CTID=${CTID:-144}
REMOTE_DIR=${REMOTE_DIR:-/root/docker-compose/gyroidvault}
SSH_OPTS=(-o ConnectTimeout=30 -o ControlPath=none)

FILES=(
  "server/index.js:index.js"
  "server/utils/library.js:library.js"
  "server/utils/f3d.js:f3d.js"
  "public/js/app.js:app.js"
  "public/js/components.js:components.js"
  "public/js/viewer.js:viewer.js"
  "public/js/stl-worker.js:stl-worker.js"
)

cd "$(dirname "$0")/.."

branch=$(git branch --show-current)
[ "$branch" = "deploy" ] || { echo "refusing: on branch '$branch', expected 'deploy'"; exit 1; }
git diff --quiet || { echo "refusing: uncommitted changes"; exit 1; }

for pair in "${FILES[@]}"; do
  node --check "${pair%%:*}" || { echo "refusing: ${pair%%:*} failed syntax check"; exit 1; }
done
echo "syntax ok, $(git rev-parse --short HEAD) on $branch"

ssh "${SSH_OPTS[@]}" "$PVE" "pct exec $CTID -- sh -c 'mkdir -p $REMOTE_DIR/backup && cp $REMOTE_DIR/data/gyroidvault.db $REMOTE_DIR/backup/gyroidvault-\$(date +%Y%m%d-%H%M%S).db'"
echo "database backed up"

for pair in "${FILES[@]}"; do
  src="${pair%%:*}"; dst="${pair##*:}"
  scp "${SSH_OPTS[@]}" -q "$src" "$PVE:/tmp/gvsync-$dst"
  ssh "${SSH_OPTS[@]}" "$PVE" "pct push $CTID /tmp/gvsync-$dst $REMOTE_DIR/patch/$dst"
done

scp "${SSH_OPTS[@]}" -q deploy/docker-compose.yml "$PVE:/tmp/gvsync-compose.yml"
ssh "${SSH_OPTS[@]}" "$PVE" "pct push $CTID /tmp/gvsync-compose.yml $REMOTE_DIR/docker-compose.yml"

ssh "${SSH_OPTS[@]}" "$PVE" "pct exec $CTID -- sh -c 'cd $REMOTE_DIR && docker compose up -d'" 2>&1 | tail -3

sleep 15
code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 http://10.0.0.103:3457/ || true)
echo "health: HTTP $code"
[ "$code" = "200" ] || { echo "WARNING: service not healthy"; exit 1; }
