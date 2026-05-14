# shellcheck shell=bash
: "${PGCONNECT_TIMEOUT:=10}"
: "${PGKEEPALIVES_IDLE:=30}"
: "${PGKEEPALIVES_INTERVAL:=10}"
: "${PGKEEPALIVES_COUNT:=3}"
export PGCONNECT_TIMEOUT PGKEEPALIVES_IDLE PGKEEPALIVES_INTERVAL PGKEEPALIVES_COUNT

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

  if lambda_enabled; then
    local filename
    filename=$(basename "$file")
    lambda_invoke "$(lambda_payload_with_file apply "$dburl" "$filename" "$file")"
    return
  fi

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

  if lambda_enabled; then
    local pending pending_file rc
    pending=$(cat)
    [[ -n $pending ]] || return 0
    # `awk -v pending="$pending"` would error on BSD awk ("newline in string")
    # because pending is multi-line. Pass it via a temp file instead.
    pending_file=$(mktemp)
    printf '%s' "$pending" >"$pending_file"
    lambda_invoke "$(lambda_payload_simple status "$dburl")" \
      | awk -F'\t' -v pf="$pending_file" '
          BEGIN {
            while ((getline line < pf) > 0) if (line != "") keep[line] = 1
            close(pf)
          }
          $2 == "applied" && ($1 in keep) { print $1 "|" $3 }
        ' \
      | sort
    rc=$?
    rm -f "$pending_file"
    return "$rc"
  fi

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
  local dburl=$1

  if lambda_enabled; then
    lambda_invoke "$(lambda_payload_simple status "$dburl")" \
      | awk -F'\t' '$2 == "applied" { print $1 "|" $3 }' \
      | sort
    return
  fi

  db_query "$dburl" \
    "SELECT timestamp || '|' || description FROM migrations ORDER BY timestamp"
}

db_mark_missing() {
  local dburl=$1

  if lambda_enabled; then
    local line ts desc filename tmpfile
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      ts=${line%%|*}
      desc=${line#*|}
      [[ $ts =~ ^[0-9]{10}$ || $ts =~ ^[0-9]{14}$ ]] || continue
      filename="${ts}_marked.sql"
      tmpfile=$(mktemp)
      printf -- '-- %s\n' "$desc" >"$tmpfile"
      if lambda_invoke "$(lambda_payload_with_file mark "$dburl" "$filename" "$tmpfile")" >/dev/null; then
        printf '%s\n' "$ts"
      fi
      rm -f "$tmpfile"
    done
    return
  fi

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

  if lambda_enabled; then
    local filename="${ts}_marked.sql" tmpfile rc
    tmpfile=$(mktemp)
    printf -- '-- %s\n' "$desc" >"$tmpfile"
    lambda_invoke "$(lambda_payload_with_file mark "$dburl" "$filename" "$tmpfile")" >/dev/null
    rc=$?
    rm -f "$tmpfile"
    return "$rc"
  fi

  local esc=${desc//\'/\'\'}
  db_exec "$dburl" \
    "INSERT INTO migrations(timestamp, description) VALUES ('$ts', '$esc')"
}

db_delete_migration() {
  local dburl=$1 ts=$2

  if lambda_enabled; then
    if lambda_invoke "$(lambda_payload_unmark "$dburl" "${ts}_unmark.sql")" >/dev/null; then
      printf '1\n'
    fi
    return 0
  fi

  db_query "$dburl" \
    "DELETE FROM migrations WHERE timestamp = '$ts' RETURNING 1"
}

db_has_migrations_table() {
  local dburl=$1

  if lambda_enabled; then
    printf 't'
    return 0
  fi

  psql "$dburl" -v ON_ERROR_STOP=1 -X -tAc \
    "SELECT to_regclass('public.migrations') IS NOT NULL"
}
