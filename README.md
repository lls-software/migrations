# migrations.sh

A single-file Bash tool for SQL-first, forward-only Postgres migrations.

Migrations are plain `.sql` files. The tool runs them against a database, tracks what's been applied in a dedicated table, and stays out of your way otherwise. No DSL, no ORM, no runtime beyond `bash` and `psql`.

## Getting Started

Drop `migrations.sh` into your project:

```bash
curl -L -o migrations.sh https://download.migrations.sh/
chmod +x migrations.sh
git add migrations.sh
```

Initialize:

```bash
./migrations.sh init                    # creates migrations/ and .migrationsrc
./migrations.sh setup "$DATABASE_URL"   # creates the migrations tracking table
```

Write and apply a migration:

```bash
./migrations.sh new "Add orders table"  # creates migrations/<ts>_add_orders_table.sql
# ...edit the file...
./migrations.sh status "$DATABASE_URL"
./migrations.sh apply  "$DATABASE_URL"
```

Adopting an existing project whose schema is already applied:

```bash
./migrations.sh init
./migrations.sh setup "$DATABASE_URL"
./migrations.sh mark --all "$DATABASE_URL"   # record every on-disk file as applied
```

## How It Works

### Two stores, different lifetimes

```
  repo (short rolling tail)                database (unbounded log)
  ─────────────────────────                ────────────────────────
  migrations/                              migrations table
  ├── 20260118093012_add_orders.sql        ├── 20250403...  add_users
  ├── 20260122141055_index_email.sql       ├── 20250615...  rename_column
  └── 20260123094512_backfill_totals.sql   ├── ...
                                           ├── 20260118...  add_orders
         apply                             ├── 20260122...  index_email
  ──────────────────►                      └── 20260123...  backfill_totals
```

The **directory** holds only migrations still rolling out across environments. Once a migration has shipped everywhere, delete the file from the repo. The **tracking table** is the forever-log of every migration that ever ran against a given database; `status --history` surfaces rows whose files are gone.

This is why the project expects a `schema.sql` alongside `migrations/`: fresh deployments build from `schema.sql` (current state), and `migrations/` exists for transitions between releases. Applying hundreds of historical migrations to a new environment is as wrong as installing the first version of an OS and then running years of updates to catch up.

### Applying a migration

1. `migrations.sh apply <dburl>` lists `migrations/*.sql` and sorts by the leading timestamp.
2. For each file on disk, the tool asks the database which are already recorded (`JOIN` against the file timestamps only — the full history is never fetched).
3. Unapplied files run in timestamp order. Each file runs inside a single transaction that also inserts the tracking row:

   ```
   psql --single-transaction -f <migration>.sql -c "INSERT INTO migrations …"
   ```

   A failing migration leaves zero trace: no partial DDL, no orphan row.
4. Files marked `-- migrations.sh: no-transaction` in their header run outside a transaction, and the tracking row is inserted as a separate statement afterward. Use this sparingly, for operations Postgres forbids inside transactions (`CREATE INDEX CONCURRENTLY`, `ALTER TYPE … ADD VALUE` on older Postgres, `VACUUM`). Keep such migrations small: if the SQL commits but the tracking insert fails, the next `apply` will re-run the file.

### Migration files

```sql
-- Add orders table
CREATE TABLE orders (...);
```

The first comment line is the human-readable description. `migrations.sh new "Add orders table"` creates the file with a UTC timestamp and a slugified filename:

```
migrations/20260123094512_add_orders_table.sql
```

Timestamps can be 14 digits (`YYYYMMDDHHMMSS`, the current format) or 10 digits (seconds since the Unix epoch, from earlier versions). Both sort chronologically.

### Keeping schema.sql in sync

There's no wrong answer; pick what works for your team:

- **Edit together.** When you write a migration, update `schema.sql` in the same change to reflect the post-migration state.
- **Dump after apply.** After `apply`, run `pg_dump --schema-only` and commit the result.

### Reconciliation, not rollback

There is no `down` command. Many database changes (`DROP TABLE`, data backfills) cannot be reversed, and encoding rollback paths creates false confidence that deploys can be undone. When something goes wrong, fix it with a new forward migration.

For drift between files and database, the tool provides `mark` (record as applied without running) and `unmark` (remove the tracking row). These are manual repair tools, not a rollback mechanism.

## Commands

| Command | Purpose |
| --- | --- |
| `init [--dir <path>]` | Create `migrations/` and `.migrationsrc` in the current repo. |
| `setup <dburl>` | Create the `migrations` tracking table. Idempotent. |
| `new [--no-transaction] <description>` | Create a new timestamped migration file. |
| `status [--history] <dburl>` | Show pending migrations. With `--history`, also show rows whose files are gone. |
| `apply <dburl>` | Run all pending migrations in timestamp order. |
| `mark <dburl> (<timestamp> \| --all) [--description <text>] [--force]` | Record a migration as applied without running it. |
| `unmark <dburl> <timestamp>` | Remove a row from the tracking table. |

`<dburl>` is any Postgres connection string `psql` accepts. Standard `PG*` environment variables (`PGHOST`, `PGUSER`, `PGPASSWORD`, …) work as you'd expect.

## Configuration

`.migrationsrc` lives at the repo root. The tool walks up from `$PWD` to find it (stopping at the git root).

```ini
dir=migrations
```

`dir` is the migrations directory, relative to the config file. If no `.migrationsrc` is found, the tool defaults to `./migrations`.

## Running against a VPC-bound database

The usual answer to "the database isn't reachable from my laptop" is a **bastion host** — an EC2 instance in the VPC that you SSH-tunnel through (`ssh -L 5432:db.internal:5432 bastion`), then run `psql postgres://localhost`. You own and pay for the bastion 24/7, manage SSH keys and OS patches, and every byte of query traffic crosses the internet twice (laptop → bastion → database → bastion → laptop).

`migrations.sh` ships an alternative: package the migration runner as an **AWS Lambda function**, deploy it inside the VPC, and have the CLI invoke it on demand. No long-running host, no SSH keys, no double network hop, and the function is effectively free while idle. You only pay for invocations — pennies a month for a migration tool.

The DB-touching commands (`setup`, `status`, `apply`, `mark`, `unmark`) accept `--lambda-arn <arn-or-name>` to engage this mode:

```bash
./migrations.sh apply --lambda-arn migrations "$DATABASE_URL"
```

The flag value can be a full ARN (`arn:aws:lambda:us-east-1:…:function:migrations`) or just the function name. Region and credentials come from your standard AWS CLI environment (`AWS_PROFILE`, `AWS_REGION`).

Behind the flag, the CLI wraps each command in a JSON-RPC 2.0 request (filename, file content for `apply`/`mark`, the connection string) and invokes the Lambda via `aws lambda invoke`. The Lambda — inside the VPC, with direct network access to the database — runs the **exact same `migrations.sh`** baked into its container image, and the combined `psql` stdout/stderr is returned synchronously and printed to your terminal. Lambda's 6 MB response payload cap applies, which is plenty for typical migrations.

- **Same script, both modes.** The Lambda's container ships `migrations.sh` itself and shells out to it — transaction handling, the `-- migrations.sh: no-transaction` header directive, the tracking-table schema, `ON_ERROR_STOP` semantics all live in one place. No second implementation to drift out of sync with the one you run locally.
- **No stored secrets.** The Lambda holds no database credentials and needs no `secretsmanager:*` permissions. The connection string travels in the invocation payload, so rotation and revocation work exactly as they do for local-mode users.
- **Stateless, immutable images.** A new version of `migrations.sh` is a new container tag (`v0.2.0`, `v0.3.0`, …). Roll forward by pointing the Lambda at a new image URI; roll back by pointing it at the old one.

Requirements for Lambda mode (local-mode users don't need these):

- `jq` — for safe JSON payload construction
- `aws` CLI v2

The Lambda is built and published from this repo (`lambda/Dockerfile`); see `lambda/handler.ts` for the JSON-RPC 2.0 protocol it speaks.

### Deploying the Lambda

Pre-built arm64 images are published to ECR and pullable from any AWS account. Pin to a specific version — no `latest` tag.

```
144273415340.dkr.ecr.<region>.amazonaws.com/migrations:v0.2.3
```

Available in: `us-east-1`, `us-east-2`, `us-west-2`, `ca-central-1`, `sa-east-1`, `eu-west-1`, `eu-central-1`, `eu-west-2`, `ap-southeast-1`, `ap-northeast-1`, `ap-south-1`, `ap-southeast-2`. Use the URI for the same region as your database.

Minimum Lambda configuration:

| Setting | Value |
| --- | --- |
| Package type | Container image |
| Architecture | `arm64` |
| Image URI | The ECR URI above |
| Memory | 256 MB (psql is light; bump for very large migrations) |
| Timeout | 900 s (the maximum; lets long migrations finish) |
| VPC | Same VPC/subnets as your database, with a security group that can reach the database on its port |
| Execution role | `AWSLambdaBasicExecutionRole` + `AWSLambdaVPCAccessExecutionRole`. No DB or secret permissions needed — credentials travel in the request payload. |

Grant your CLI principal `lambda:InvokeFunctionWithResponseStream` on the function ARN.

Note on credentials: the connection string is passed in the invocation payload. By default the handler does not log it; AWS doesn't auto-log Lambda event payloads to CloudWatch. Be careful enabling CloudTrail data events for Lambda invocations or third-party observability that captures request bodies — those *would* capture the dburl.

## Development

`migrations.sh` is built by concatenating `src/*.sh`:

```
├── src/               Source modules
│   ├── main.sh        Command dispatcher
│   ├── cmd_*.sh       One file per subcommand
│   ├── config.sh      .migrationsrc discovery and parsing
│   ├── db.sh          psql wrappers and SQL (with Lambda-mode dispatch)
│   ├── fs.sh          Migration file I/O and header parsing
│   ├── lambda.sh      JSON-RPC payload helpers and aws CLI invocation
│   └── util.sh        Logging, slugify, timestamp
├── build.sh           Concatenates src/*.sh into migrations.sh
├── VERSION            Version string stamped into the built artifact
└── migrations.sh      Built artifact (gitignored; produced by build.sh)
```

Build:

```bash
./build.sh
```

## Credits

Inspired by Dimitri Fontaine's *The Art of PostgreSQL*, which argues for treating SQL as a first-class language rather than something an ORM hides. `migrations.sh` is an attempt to apply that stance to schema change: plain SQL files, `psql` as the runtime, a DBA can read every migration.

## License

MIT — see [LICENSE](LICENSE).
