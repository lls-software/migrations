# shellcheck shell=bash
log_info() {
  printf 'migrations.sh: %s\n' "$*"
}

log_warn() {
  :  # TODO
}

log_error() {
  printf 'migrations.sh: error: %s\n' "$*" >&2
}

die() {
  log_error "$*"
  exit 1
}

timestamp_now() {
  :  # TODO
}

slugify() {
  :  # TODO
}
