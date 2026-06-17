# Docker Stack Reference Extras

This companion note adds three things on top of `STACK_DOCUMENTATION.md`:

- simple architecture diagrams
- sample connection strings for common app setups
- troubleshooting notes for common Docker issues

---

## Architecture Diagrams

## High-level local development view

```text
                      ┌───────────────────────┐
                      │   Your Application    │
                      │  Node / Nest / Prisma │
                      └───────────┬───────────┘
                                  │
         ┌────────────────────────┼───────────────────────────────┐
         │                        │                               │
         ▼                        ▼                               ▼
┌────────────────┐      ┌──────────────────┐            ┌────────────────────┐
│ Redis          │      │ RabbitMQ         │            │ PostgreSQL         │
│ localhost:6379 │      │ localhost:5672   │            │ localhost:5432     │
└───────┬────────┘      │ UI: :15672       │            │ pgvector enabled   │
        │               └──────────────────┘            └────────────────────┘
        │
        ▼
┌────────────────────┐
│ RedisInsight UI    │
│ localhost:5540     │
└────────────────────┘
```

## Compose view

```text
~/Documents/Local-docker-stack/
│
├── .env
├── .env.example
├── docker-compose.yml
│    ├── redis
│    ├── redisinsight
│    ├── rabbitmq
│    └── postgres
│
└── postgres/init/
     └── 01-init-multiple-dbs.sh
          ├── reads APP_DATABASES
          ├── creates databases
          └── enables vector extension
```

## PostgreSQL init flow

```text
 docker compose up -d
         │
         ▼
 Docker starts postgres container
         │
         ▼
 Reads variables from .env
         │
         ▼
 Checks if /var/lib/postgresql/data is empty
         │
         ├── No → skip init scripts
         │
         └── Yes
              │
              ▼
   Runs files in /docker-entrypoint-initdb.d
              │
              ▼
   01-init-multiple-dbs.sh executes
              │
              ├── reads APP_DATABASES
              ├── creates app_db
              ├── creates messaging_db
              ├── creates platform_db
              └── enables vector in each database
```

---

## Sample Connection Strings

### PostgreSQL main app

```text
postgresql://postgres:postgres@localhost:5432/app_db
```

### PostgreSQL messaging app

```text
postgresql://postgres:postgres@localhost:5432/messaging_db
```

### PostgreSQL agency app

```text
postgresql://postgres:postgres@localhost:5432/platform_db
```

### Redis

```text
redis://localhost:6379
```

### RabbitMQ

```text
amqp://appuser:local_dev_password@localhost:5672
```

---

## Node.js examples

## PostgreSQL with `pg`

```js
import pg from "pg";

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});

const result = await pool.query("SELECT NOW()");
console.log(result.rows[0]);
```

## Redis with `ioredis`

```js
import Redis from "ioredis";

const redis = new Redis(process.env.REDIS_URL);

await redis.set("hello", "world");
console.log(await redis.get("hello"));
```

## RabbitMQ with `amqplib`

```js
import amqp from "amqplib";

const connection = await amqp.connect(process.env.RABBITMQ_URL);
const channel = await connection.createChannel();

await channel.assertQueue("jobs");
await channel.sendToQueue("jobs", Buffer.from("hello"));
```

---

## NestJS examples

```ts
export default () => ({
  databaseUrl: process.env.DATABASE_URL,
  messagingDatabaseUrl: process.env.MESSAGING_DATABASE_URL,
  agencyDatabaseUrl: process.env.AGENCY_DATABASE_URL,
  redisUrl: process.env.REDIS_URL,
  rabbitmqUrl: process.env.RABBITMQ_URL,
});
```

```ts
TypeOrmModule.forRoot({
  type: "postgres",
  url: process.env.DATABASE_URL,
  autoLoadEntities: true,
  synchronize: false,
});
```

---

## Prisma example

```env
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/app_db"
```

```prisma
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}
```

---

## RedisInsight Usage Notes

Open:

```text
http://localhost:5540
```

Typical flow:

1. Open the UI.
2. Add a Redis connection.
3. Use host `localhost` and port `6379` from your machine.

---

## Troubleshooting

## 1. `.env` changes do not seem applied

Recreate services:

```bash
docker compose up -d --force-recreate
```

---

## 2. RedisInsight does not start

Check logs:

```bash
docker compose logs -f redisinsight
```

Make sure Redis is healthy and port `5540` is free.

---

## 3. RabbitMQ login fails

Verify:

- `RABBITMQ_DEFAULT_USER` in `.env`
- `RABBITMQ_DEFAULT_PASS` in `.env`
- `RABBITMQ_URL` used by your app

---

## 4. Postgres databases are missing after changing `APP_DATABASES`

The init script only runs on first initialization.

If resetting data is okay:

```bash
docker compose down -v
docker compose up -d
```

---

## 5. Health check says `unhealthy`

Helpful commands:

```bash
docker ps
docker inspect myredis
docker inspect rabbitmq
docker inspect postgres-pgvector
docker inspect redisinsight
```

---

## Quick Study Summary

### Compose responsibilities

- define Redis, RedisInsight, RabbitMQ, and Postgres
- expose local ports
- apply persistent volumes
- define health checks
- inject credentials and DB names from `.env`

### Init script responsibilities

- read `APP_DATABASES`
- split it into an array
- loop through each name
- create missing databases
- enable `vector` in each database

