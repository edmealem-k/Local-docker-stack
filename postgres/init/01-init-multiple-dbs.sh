#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${APP_DATABASES:-}" ]]; then
  echo "APP_DATABASES is empty; skipping extra database creation"
  exit 0
fi

IFS=',' read -ra DBS <<< "$APP_DATABASES"

for db in "${DBS[@]}"; do
  db="$(echo "$db" | xargs)"
  if [[ -z "$db" ]]; then
    continue
  fi

  echo "Creating database: $db"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres <<SQL
SELECT 'CREATE DATABASE "$db"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db')\gexec
SQL

  echo "Enabling pgvector in: $db"
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$db" <<SQL
CREATE EXTENSION IF NOT EXISTS vector;
SQL
done
