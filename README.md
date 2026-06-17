# Docker Images Local Stack

Local development infrastructure for apps that need:

- Redis
- RedisInsight
- RabbitMQ
- PostgreSQL
- pgvector

This stack is designed for local development only and is managed with Docker Compose.

## Files

- `docker-compose.yml` — main local stack
- `.env` — your local configuration values
- `.env.example` — safe template for setup
- `postgres/init/01-init-multiple-dbs.sh` — first-run PostgreSQL bootstrap
- `STACK_DOCUMENTATION.md` — detailed architecture and explanation
- `STACK_REFERENCE_EXTRAS.md` — diagrams, examples, and troubleshooting

## Quick Start

```bash
cd ~/Documents/Local-docker-stack
cp .env.example .env
# edit .env if needed
docker compose up -d
```

## Services

- Redis: `localhost:6379`
- RedisInsight: `http://localhost:5540`
- RabbitMQ: `localhost:5672`
- RabbitMQ UI: `http://localhost:15672`
- PostgreSQL: `localhost:5432`

## Common Commands

### Start

```bash
docker compose up -d
```

### Stop

```bash
docker compose down
```

### Reset all local data

```bash
docker compose down -v
```

### Show merged config

```bash
docker compose config
```

### View logs

```bash
docker compose logs -f
```

## Notes

- PostgreSQL extra databases are created from `APP_DATABASES`.
- The init script runs only on the first Postgres volume initialization.
- If you change bootstrap DB names later, recreate volumes or create the DBs manually.

## Suggested Git Workflow

```bash
git init
git add .
git commit -m "Initial local docker stack"
```

## Study References

- See `STACK_DOCUMENTATION.md` for detailed explanations.
- See `STACK_REFERENCE_EXTRAS.md` for diagrams and app connection examples.
