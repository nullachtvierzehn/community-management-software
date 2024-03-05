#!/usr/bin/env bash

echo "run after deploy hooks ..."

# dump current schema
pg_dump "$SQITCH_TARGET" --no-sync --schema-only --no-owner --exclude-schema=graphile_migrate --exclude-schema=graphile_worker --file=../../graphql/schema/current.sql

# drop all but the latest 5 data dumps
ls -r ../migrations/current-data/dump-*.sql | tail -n +6 | xargs -I {} rm -- {}

# restore the latest data dump
PGOPTIONS='--client-min-messages=warning' psql -q -d "$SQITCH_TARGET" -f $(ls -t ../migrations/current-data/dump-*.sql | head -1)