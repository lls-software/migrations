# shellcheck shell=bash
log_info() {
  printf 'migrations.sh: %s\n' "$*"
}

log_error() {
  printf 'migrations.sh: error: %s\n' "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

timestamp_now() {
  date -u +%Y%m%d%H%M%S
}

slugify() {
  local s=$1
  s=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '_')
  while [[ $s == *__* ]]; do s=${s//__/_}; done
  s=${s#_}
  s=${s%_}
  printf '%s' "$s"
}
