#!/usr/bin/env bash

declare -a modifiedArguments=("$@")
declare tmpFile=$(mktemp)
declare originalFile

# cleanup on exit
cleanup() {
  # Delete the temporary file at exit-
  rm -f "$tmpFile"
}

trap cleanup EXIT

# Find and modify the --file option to point at $tmpFile.
for index in "${!modifiedArguments[@]}"
do
  if [[ "${modifiedArguments[index]}" == "--file" ]]
  then
    originalFile="${modifiedArguments[$((index+1))]}"
    modifiedArguments[$((index+1))]=$tmpFile
    break
  fi
done

# Import .env variables.
set -o allexport
source ../../../.env
set +o allexport

# Replace environment variables in the migration file.
envsubst < "$originalFile" > "$tmpFile"

# Set PostgreSQL environment variables from .env, if not already set to other values.
#[ ! -z "${DATABASE_OWNER}" ] && [ -z "${PGUSER}" ] && export PGUSER="${DATABASE_OWNER}"
#[ ! -z "${DATABASE_OWNER_PASSWORD}" ] && [ -z "${PGPASSWORD}" ] && export PGPASSWORD="${DATABASE_OWNER_PASSWORD}"
#[ ! -z "${DATABASE_HOST}" ] && [ -z "${PGHOST}" ] && export PGHOST="${DATABASE_HOST}"
#[ ! -z "${DATABASE_PORT}" ] && [ -z "${PGPORT}" ] && export PGPORT="${DATABASE_PORT}"
#[ ! -z "${DATABASE_NAME}" ] && [ -z "${PGDATABASE}" ] && export PGDATABASE="${DATABASE_NAME}"

# Call psql.
psql "${modifiedArguments[@]}"
