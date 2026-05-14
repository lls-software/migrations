# shellcheck shell=bash
cmd_unmark() {
  local dburl=''
  local ts=''

  while (( $# )); do
    case $1 in
      --lambda-arn)
        LAMBDA_ARN=${2-}
        [[ -n $LAMBDA_ARN ]] || die "unmark: --lambda-arn requires a value"
        shift 2
        ;;
      --lambda-arn=*)
        LAMBDA_ARN=${1#--lambda-arn=}
        shift
        ;;
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

  if lambda_enabled; then lambda_require_deps; fi

  if [[ $(db_has_migrations_table "$dburl") != t ]]; then
    die "migrations table not found; run: migrations.sh setup <dburl>"
  fi

  local result
  result=$(db_delete_migration "$dburl" "$ts")
  [[ -n $result ]] || die "unmark: no row for $ts"
  log_info "unmarked $ts"
}
