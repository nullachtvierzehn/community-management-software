#!/usr/bin/env bash

# Import .env variables.
set -o allexport
source ../../../.env
set +o allexport

[ ! -z "${DATABASE_OWNER}" ] && [ -z "${PGUSER}" ] && export PGUSER="${DATABASE_OWNER}"
[ ! -z "${DATABASE_OWNER_PASSWORD}" ] && [ -z "${PGPASSWORD}" ] && export PGPASSWORD="${DATABASE_OWNER_PASSWORD}"
[ ! -z "${DATABASE_HOST}" ] && [ -z "${PGHOST}" ] && export PGHOST="${DATABASE_HOST}"
[ ! -z "${DATABASE_PORT}" ] && [ -z "${PGPORT}" ] && export PGPORT="${DATABASE_PORT}"
[ ! -z "${DATABASE_NAME}" ] && [ -z "${PGDATABASE}" ] && export PGDATABASE="${DATABASE_NAME}"

#if [[ ! -z "${DATABASE_OWNER}" && ! -z "${DATABASE_OWNER_PASSWORD}" && ! -z "${DATABASE_HOST}" && -z "${DATABASE_NAME}" ]]; then
#[ -z "$SQITCH_TARGET" ] && export SQITCH_TARGET="postgres://$DATABASE_OWNER:$DATABASE_OWNER_PASSWORD@$DATABASE_HOST:${DATABASE_PORT:-5432}/$DATABASE_NAME"
#[ -z "$SQITCH_USERNAME" ] && export SQITCH_USERNAME="$DATABASE_OWNER"
#[ -z "$SQITCH_PASSWORD" ] && export SQITCH_PASSWORD="$DATABASE_OWNER_PASSWORD"
#fi

#set -- sqitch \
#  --set "idm_schema=app_public" \
#  --set "id_schema=app_public" \
#  --set "app_public=app_public" \
#  --set "utils_schema=app_hidden" \
#  "$@"

set -- sqitch \
  "$@"

exec "$@"