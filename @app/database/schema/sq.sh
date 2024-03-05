#!/usr/bin/env bash

declare -a arguments=("$@")

# Import .env variables.
set -o allexport
source ../../../.env
set +o allexport

#[ ! -z "${DATABASE_OWNER}" ] && [ -z "${PGUSER}" ] && export PGUSER="${DATABASE_OWNER}"
#[ ! -z "${DATABASE_OWNER_PASSWORD}" ] && [ -z "${PGPASSWORD}" ] && export PGPASSWORD="${DATABASE_OWNER_PASSWORD}"
#[ ! -z "${DATABASE_HOST}" ] && [ -z "${PGHOST}" ] && export PGHOST="${DATABASE_HOST}"
#[ ! -z "${DATABASE_PORT}" ] && [ -z "${PGPORT}" ] && export PGPORT="${DATABASE_PORT}"
#[ ! -z "${DATABASE_NAME}" ] && [ -z "${PGDATABASE}" ] && export PGDATABASE="${DATABASE_NAME}"

# Detect subcommand
for arg in "$@"; do
  if [[ "$arg" == "deploy" ]] || [[ "$arg" == "revert" ]] || [[ "$arg" == "rebase" ]]; then
    sub_command="$arg"
    break
  fi
done

# Has a target?
has_target=0
found_target=""

for index in "${!arguments[@]}"
do
  if [[ "${arguments[index]}" == "--target" ]] || [[ "${arguments[index]}" == "-t" ]]
  then
    has_target=1
    found_target="${arguments[$((index+1))]}"
    break
  fi
done

# Export target
if [[ $has_target -eq 1 ]] && [[ -z "${SQITCH_TARGET}" ]]; then
  export SQITCH_TARGET=$found_target
fi

if [[ $has_target -eq 0 ]] && [[ -z "${SQITCH_TARGET}" ]]; then
  export SQITCH_TARGET="postgres://$DATABASE_OWNER:$DATABASE_OWNER_PASSWORD@$DATABASE_HOST:${DATABASE_PORT:-5432}/$DATABASE_NAME"
fi

# Prepend all arguments with `sqitch`.
# You could use variables.
#set -- sqitch \
#  --set "variable=value" \
#  --set "another_variable=another_value" \
#  "$@"
set -- sqitch \
  "$@"

# Run before-revert.sh for subcommands revert or rebase.
if [[ "$sub_command" == "revert" ]] || [[ "$sub_command" == "rebase" ]]; then
  ./before-revert.sh
fi

# Run command.
"$@"
sqitch_exit_status=$?

# Run after-deploy.sh for subcommands deploy or rebase.
if [[ "$sub_command" == "deploy" ]] || [[ "$sub_command" == "rebase" ]]; then
  ./after-deploy.sh
fi

exit $sqitch_exit_status