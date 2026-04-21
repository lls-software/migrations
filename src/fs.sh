# shellcheck shell=bash
fs_list_migrations() {
  :  # TODO
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
