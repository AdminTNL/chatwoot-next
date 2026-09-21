#!/bin/sh
set -x

rm -rf /app/tmp/pids/server.pid
rm -rf /app/tmp/cache/*

# node_modules lives in a named volume that survives container restarts, so a full
# reinstall is only needed when that volume is cold or incomplete. Pruning the store
# and forcing a reinstall on every boot re-downloads every package (~15 min).
if [ -d /app/node_modules/.pnpm ] && [ -f /app/node_modules/.modules.yaml ]; then
  echo "node_modules already populated, syncing dependencies."
  pnpm install --frozen-lockfile --prefer-offline
else
  echo "node_modules missing or incomplete, running a full install."
  pnpm store prune
  pnpm install --force
fi

echo "Ready to run Vite development server."

exec "$@"
