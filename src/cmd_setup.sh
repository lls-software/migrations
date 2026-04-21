# shellcheck shell=bash
cmd_setup() {
  local dburl=${1-}
  [[ -n $dburl ]] || die "setup: missing <dburl>"

  if [[ $(db_has_migrations_table "$dburl") == t ]]; then
    log_info "migrations table already present"
    return 0
  fi

  db_exec "$dburl" "CREATE TABLE IF NOT EXISTS migrations (
    timestamp   text        PRIMARY KEY,
    description text        NOT NULL,
    applied_at  timestamptz NOT NULL DEFAULT now()
  );"
  log_info "created migrations table"
}
