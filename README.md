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
  repo (short rolling tail)          database (unbounded log)
  ─────────────────────────          ────────────────────────
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

## Development

`migrations.sh` is built by concatenating `src/*.sh`:

```
├── src/               Source modules
│   ├── main.sh        Command dispatcher
│   ├── cmd_*.sh       One file per subcommand
│   ├── config.sh      .migrationsrc discovery and parsing
│   ├── db.sh          psql wrappers and SQL
│   ├── fs.sh          Migration file I/O and header parsing
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
