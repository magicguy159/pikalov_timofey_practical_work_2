#!/usr/bin/env bash
set -euo pipefail

: "\${PGDATABASE:?Set PGDATABASE to the target database}"
: "\${PGUSER:?Set PGUSER to a PostgreSQL administrator}"

pg_dump --format=custom --schema=pikalov_food \
  --file=db/foodexpress_pikalov.backup \
  "$PGDATABASE"

echo "Created db/foodexpress_pikalov.backup"
