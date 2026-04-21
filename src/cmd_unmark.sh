# shellcheck shell=bash
cmd_unmark() {
  local dburl=''
  local ts=''

  while (( $# )); do
    case $1 in
      -*)
        die "unmark: unknown option: $1"
        ;;
      *)
        if [[ -z $dburl ]]; then
          dburl=$1
        elif [[ -z $ts ]]; then
          ts=$1
        else
          die "unmark: unexpected argument: $1"
        fi
        shift
        ;;
    esac
  done

  [[ -n $dburl ]] || die "unmark: missing <dburl>"
  [[ -n $ts ]] || die "unmark: missing <timestamp>"
  [[ $ts =~ ^[0-9]{10}$ || $ts =~ ^[0-9]{14}$ ]] \
    || die "unmark: invalid timestamp: $ts"

  if [[ $(db_has_migrations_table "$dburl") != t ]]; then
    die "migrations table not found; run: migrations.sh setup <dburl>"
  fi

  local result
  result=$(db_delete_migration "$dburl" "$ts")
  [[ -n $result ]] || die "unmark: no row for $ts"
  log_info "unmarked $ts"
}
