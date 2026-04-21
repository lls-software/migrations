# shellcheck shell=bash
db_query() {
  local dburl=$1 sql=$2
  psql "$dburl" -v ON_ERROR_STOP=1 -X -tAc "$sql"
}

db_exec() {
  local dburl=$1 sql=$2
  psql "$dburl" -v ON_ERROR_STOP=1 -X -q -c "$sql"
}

db_apply_file() {
  :  # TODO
}

db_pending_set() {
  local dburl=$1
  local values
  values=$(awk 'NF { printf "%s('\''%s'\'')", sep, $0; sep="," }')
  [[ -n $values ]] || return 0
  db_query "$dburl" \
    "SELECT v.t FROM (VALUES $values) AS v(t)
     LEFT JOIN migrations m ON m.timestamp = v.t
     WHERE m.timestamp IS NULL
     ORDER BY v.t"
}

db_list_applied() {
  db_query "$1" \
    "SELECT timestamp || '|' || description FROM migrations ORDER BY timestamp"
}

db_has_migrations_table() {
  local dburl=$1
  psql "$dburl" -v ON_ERROR_STOP=1 -X -tAc \
    "SELECT to_regclass('public.migrations') IS NOT NULL"
}
