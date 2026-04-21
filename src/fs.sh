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
  local line n=0
  while IFS= read -r line; do
    (( n++ < 5 )) || break
    [[ $line == '--'* ]] || break
    [[ $line == '-- migrations.sh: '* ]] && continue
    printf '%s' "${line#-- }"
    return
  done < "$1"
  printf '%s' ''
}

fs_find_migration() {
  local dir=$1 ts=$2
  local f
  for f in "$dir/${ts}"_*.sql "$dir/${ts}.sql"; do
    [[ -e $f ]] || continue
    fs_read_description "$f"
    return 0
  done
  return 1
}

fs_find_migration_path() {
  local dir=$1 ts=$2
  local f
  for f in "$dir/${ts}"_*.sql "$dir/${ts}.sql"; do
    [[ -e $f ]] || continue
    printf '%s\n' "$f"
    return 0
  done
  return 1
}

fs_new_migration() {
  local dir=$1 timestamp=$2 slug=$3 description=$4
  local path="$dir/${timestamp}_${slug}.sql"
  printf -- '-- %s\n' "$description" > "$path"
  printf '%s\n' "$path"
}

fs_read_header_directive() {
  local file=$1 directive=$2
  local line n=0
  while IFS= read -r line; do
    (( n++ < 5 )) || break
    [[ $line == '--'* ]] || break
    [[ $line == "-- migrations.sh: $directive" ]] && return 0
  done < "$file"
  return 1
}
