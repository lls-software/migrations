# shellcheck shell=bash
config_find() {
  local dir=$PWD
  while true; do
    [[ -f $dir/.migrationsrc ]] && { printf '%s\n' "$dir/.migrationsrc"; return; }
    [[ -d $dir/.git ]] && return 1
    [[ $dir == / ]] && return 1
    dir=${dir%/*}
  done
}

config_read_dir() {
  local file=$1
  local cfg_dir=${file%/*}
  local val
  val=$(grep -v '^#' -- <"$file" 2>/dev/null | grep '^dir=' | head -1 | cut -d= -f2-)
  if [[ -n $val ]]; then
    if [[ $val == /* ]]; then
      printf '%s\n' "$val"
    else
        printf '%s\n' "$cfg_dir/$val"
    fi
  else
    printf '%s\n' "$cfg_dir/migrations"
  fi
}

config_get_dir() {
  local file
  if file=$(config_find); then
    config_read_dir "$file"
  else
    printf '%s\n' ./migrations
  fi
}