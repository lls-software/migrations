# shellcheck shell=bash
db_query() {
  :  # TODO
}

db_exec() {
  local dburl=$1 sql=$2
  psql "$dburl" -v ON_ERROR_STOP=1 -X -q -c "$sql"
}

db_apply_file() {
  :  # TODO
}

db_list_applied() {
  :  # TODO
}

db_has_migrations_table() {
  local dburl=$1
  psql "$dburl" -v ON_ERROR_STOP=1 -X -tAc \
    "SELECT to_regclass('public.migrations') IS NOT NULL"
}
