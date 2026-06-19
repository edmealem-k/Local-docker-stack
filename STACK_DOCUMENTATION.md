# Local Docker Stack Documentation

This document explains how the local Docker stack works, why each block exists, and how to run and customize it later.

## Goal

This stack gives you one command to run the local infrastructure your apps need:

- `Redis`
- `RedisInsight`
- `RabbitMQ`
- `PostgreSQL`
- `pgvector`

It also creates multiple PostgreSQL databases automatically:

- `app_db`
- `messaging_db`
- `platform_db`

---

## Folder Structure

```text
~/Documents/Local-docker-stack/
├── .env
├── .env.example
├── docker-compose.yml
├── STACK_DOCUMENTATION.md
├── STACK_REFERENCE_EXTRAS.md
└── postgres/
    └── init/
        └── 01-init-multiple-dbs.sh
```

### What each file does

- `.env`
  - Stores your local values for ports, image tags, database names, and credentials.
- `.env.example`
  - Template you can copy for another machine or teammate.
- `docker-compose.yml`
  - Defines the full local development stack.
- `postgres/init/01-init-multiple-dbs.sh`
  - Runs automatically the first time PostgreSQL initializes its data directory.
  - Creates extra databases.
  - Enables the `vector` extension in each database.

---

## The Environment Files

## `.env`

This file is automatically read by Docker Compose.
It keeps values out of the compose YAML so the stack is easier to customize.

Example values used in this setup:

```env
COMPOSE_PROJECT_NAME=local-docker-stack

REDIS_IMAGE=redis:8.0-rc1
REDIS_PORT=6379
REDISINSIGHT_PORT=5540

RABBITMQ_IMAGE=rabbitmq:4-management
RABBITMQ_PORT=5672
RABBITMQ_UI_PORT=15672
RABBITMQ_DEFAULT_USER=appuser
RABBITMQ_DEFAULT_PASS=local_dev_password

POSTGRES_IMAGE=pgvector/pgvector:pg17
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
APP_DATABASES=app_db,messaging_db,platform_db
```

### Why this is useful

- easier to rotate credentials
- easier to change ports without editing compose YAML
- easier to share a safe template using `.env.example`

## `.env.example`

This file is a non-secret template.
It shows which variables are required, but avoids storing real local secrets.

Typical workflow:

```bash
cp .env.example .env
```

Then edit `.env` with your actual local values.

---

## The Compose File

```yaml
services:
  redis:
    image: ${REDIS_IMAGE}
    container_name: myredis
    ports:
      - "${REDIS_PORT}:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    restart: unless-stopped

  redisinsight:
    image: redis/redisinsight:latest
    container_name: redisinsight
    ports:
      - "${REDISINSIGHT_PORT}:5540"
    volumes:
      - redisinsight_data:/data
    depends_on:
      redis:
        condition: service_healthy
    healthcheck:
      test:
        [
          "CMD-SHELL",
          "wget -q -O - http://127.0.0.1:5540/ >/dev/null 2>&1 || exit 1",
        ]
      interval: 20s
      timeout: 10s
      retries: 5
      start_period: 30s
    restart: unless-stopped

  rabbitmq:
    image: ${RABBITMQ_IMAGE}
    container_name: rabbitmq
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_DEFAULT_USER}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_DEFAULT_PASS}
    ports:
      - "${RABBITMQ_PORT}:5672"
      - "${RABBITMQ_UI_PORT}:15672"
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    healthcheck:
      test: ["CMD", "rabbitmq-diagnostics", "check_port_connectivity"]
      interval: 15s
      timeout: 10s
      retries: 5
      start_period: 20s
    restart: unless-stopped

  postgres:
    image: ${POSTGRES_IMAGE}
    container_name: postgres-pgvector
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      APP_DATABASES: ${APP_DATABASES}
    ports:
      - "${POSTGRES_PORT}:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./postgres/init:/docker-entrypoint-initdb.d
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
    restart: unless-stopped

volumes:
  redis_data:
  redisinsight_data:
  rabbitmq_data:
  postgres_data:
```

---

## How Compose Variable Substitution Works

When Docker Compose sees syntax like:

```yaml
image: ${REDIS_IMAGE}
```

it replaces `${REDIS_IMAGE}` using the value from `.env`.

---

## Health Checks

Health checks let Docker test whether a service is really ready, not just running.

### Redis

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
```

Docker runs `redis-cli ping` inside the container.

### RedisInsight

```yaml
healthcheck:
  test:
    [
      "CMD-SHELL",
      "wget -q -O - http://127.0.0.1:5540/ >/dev/null 2>&1 || exit 1",
    ]
```

Docker checks whether the RedisInsight web UI responds.

### RabbitMQ

```yaml
healthcheck:
  test: ["CMD", "rabbitmq-diagnostics", "check_port_connectivity"]
```

This checks whether RabbitMQ is ready for connections.

### PostgreSQL

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
```

`pg_isready` checks whether PostgreSQL is ready for client connections.

---

## RedisInsight

RedisInsight gives you a web UI for browsing:

- keys
- TTL values
- data structures
- memory usage
- command activity

With the current config, it is available at:

```text
http://localhost:5540
```

### Why `depends_on` is used

```yaml
depends_on:
  redis:
    condition: service_healthy
```

This tells Compose to wait until Redis is healthy before starting RedisInsight.

---

## RabbitMQ Credentials

The RabbitMQ service uses values from `.env`:

```yaml
environment:
  RABBITMQ_DEFAULT_USER: ${RABBITMQ_DEFAULT_USER}
  RABBITMQ_DEFAULT_PASS: ${RABBITMQ_DEFAULT_PASS}
```

That means your AMQP URL is based on those values, for example:

```text
amqp://appuser:local_dev_password@localhost:5672
```

The RabbitMQ management UI uses the same username and password.

---

## PostgreSQL Init Script

```bash
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
```

This script:

- reads `APP_DATABASES` from `.env`
- creates missing databases
- enables `vector` in each database

It runs only the first time the Postgres data volume is initialized.

---

## How to Run the Stack

## Start

```bash
cd ~/Documents/Local-docker-stack
docker compose up -d
```

## Stop

```bash
docker compose down
```

## Stop and remove data volumes

```bash
docker compose down -v
```

## Validate config

```bash
docker compose config
```

## View logs

```bash
docker compose logs -f
```

---

## Connection Information

## Redis

```text
redis://localhost:6379
```

## RedisInsight

```text
http://localhost:5540
```

## RabbitMQ

```text
amqp://appuser:local_dev_password@localhost:5672
http://localhost:15672
```

## PostgreSQL

```text
postgresql://postgres:postgres@localhost:5432/app_db
```

---

## Summary

You now have a single local-development Docker Compose stack that:

- uses `.env` for configuration
- provides `.env.example` as a reusable template
- adds RedisInsight
- adds health checks
- supports custom RabbitMQ credentials
- auto-creates multiple PostgreSQL databases with `pgvector`

Main mental model:

- `docker-compose.yml` = full local infrastructure blueprint
- `.env` = configurable values injected into Compose
- init script = first-time PostgreSQL bootstrap automation
