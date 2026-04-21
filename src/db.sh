# shellcheck shell=bash
db_query() {
  local dburl=$1 sql=$2
  psql "$dburl" -v ON_ERROR_STOP=1 -X -q -tAc "$sql"
}

db_exec() {
  local dburl=$1 sql=$2
  psql "$dburl" -v ON_ERROR_STOP=1 -X -q -c "$sql"
}

db_apply_file() {
  local dburl=$1 file=$2 ts=$3 desc=$4
  local esc=${desc//\'/\'\'}
  local insert_sql="INSERT INTO migrations(timestamp, description) VALUES ('$ts', '$esc')"

  if fs_read_header_directive "$file" no-transaction; then
    psql "$dburl" -v ON_ERROR_STOP=1 -X -q -f "$file" || return 1
    db_exec "$dburl" "$insert_sql"
  else
    psql "$dburl" -v ON_ERROR_STOP=1 -X -q --single-transaction \
      -f "$file" \
      -c "$insert_sql"
  fi
}

db_applied_subset() {
  local dburl=$1
  local values
  values=$(awk 'NF { printf "%s('\''%s'\'')", sep, $0; sep="," }')
  [[ -n $values ]] || return 0
  db_query "$dburl" \
    "SELECT m.timestamp || '|' || m.description
     FROM (VALUES $values) AS v(t)
     JOIN migrations m ON m.timestamp = v.t
     ORDER BY m.timestamp"
}

db_list_applied() {
  db_query "$1" \
    "SELECT timestamp || '|' || description FROM migrations ORDER BY timestamp"
}

db_mark_missing() {
  local dburl=$1
  local values='' sep='' line ts desc esc
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    ts=${line%%|*}
    desc=${line#*|}
    [[ $ts =~ ^[0-9]{10}$ || $ts =~ ^[0-9]{14}$ ]] || continue
    esc=${desc//\'/\'\'}
    values+="${sep}('$ts','$esc')"
    sep=","
  done
  [[ -n $values ]] || return 0
  db_query "$dburl" \
    "INSERT INTO migrations(timestamp, description)
     VALUES $values
     ON CONFLICT (timestamp) DO NOTHING
     RETURNING timestamp"
}

db_insert_migration() {
  local dburl=$1 ts=$2 desc=$3
  local esc=${desc//\'/\'\'}
  db_exec "$dburl" \
    "INSERT INTO migrations(timestamp, description) VALUES ('$ts', '$esc')"
}

db_delete_migration() {
  local dburl=$1 ts=$2
  db_query "$dburl" \
    "DELETE FROM migrations WHERE timestamp = '$ts' RETURNING 1"
}

db_has_migrations_table() {
  local dburl=$1
  psql "$dburl" -v ON_ERROR_STOP=1 -X -tAc \
    "SELECT to_regclass('public.migrations') IS NOT NULL"
}
