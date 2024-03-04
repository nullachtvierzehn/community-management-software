#!/usr/bin/env bash

echo "before revert hooks ..."

pg_dump "$GM_DBURL" --data-only --schema app_public --schema app_hidden --schema app_private --on-conflict-do-nothing --column-inserts --no-comments --file ../migrations/current-data/dump-$(date +"%Y-%m-%d-T-%H-%M-%S-%3N").sql