# shellcheck shell=bash
fs_list_migrations() {
  local dir=$1
  local f base ts desc
  shopt -s nullglob
  for f in "$dir"/*.sql; do
    base=${f##*/}
    base=${base%.sql}
    ts=${base%%_*}
    [[ $ts =~ ^[0-9]{10}$ || $ts =~ ^[0-9]{14}$ ]] || continue
    desc=$(fs_read_description "$f")
    printf '%s|%s\n' "$ts" "$desc"
  done | sort
  shopt -u nullglob
}

fs_read_description() {
  local first
  IFS= read -r first < "$1" || true
  if [[ $first == '-- '* ]]; then
    printf '%s' "${first#-- }"
  else
    printf '%s' ''
  fi
}

fs_new_migration() {
  local dir=$1 timestamp=$2 slug=$3 description=$4
  local path="$dir/${timestamp}_${slug}.sql"
  printf -- '-- %s\n' "$description" > "$path"
  printf '%s\n' "$path"
}

fs_read_header_directive() {
  :  # TODO
}
