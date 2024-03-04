#!/usr/bin/env bash

# Check if an input file name is provided as an argument.
if [ -z "$1" ]; then
  echo "Usage: $0 <input_file_name>"
  exit 1
fi

# Assign the first argument as the input file name.
input_file_name="$1"

# Prepare temporary file and clean up on exit.
declare tmp_file=$(mktemp)

cleanup() {
  # Delete the temporary file at exit-
  rm -f "$tmp_file"
}

trap cleanup EXIT

# Import .env variables.
set -o allexport
source ../../../.env
set +o allexport

# Replace environment variables in the migration file.
envsubst < "$input_file_name" > "$tmp_file"

# Call psql.
psql -d "$SUPERUSER_DATABASE_URL" < $tmp_file
