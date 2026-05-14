# shellcheck shell=bash
cmd_setup() {
  local dburl=''

  while (( $# )); do
    case $1 in
      --lambda-arn)
        LAMBDA_ARN=${2-}
        [[ -n $LAMBDA_ARN ]] || die "setup: --lambda-arn requires a value"
        shift 2
        ;;
      --lambda-arn=*)
        LAMBDA_ARN=${1#--lambda-arn=}
        shift
        ;;
      -*)
        die "setup: unknown option: $1"
        ;;
      *)
        [[ -z $dburl ]] || die "setup: unexpected argument: $1"
        dburl=$1
        shift
        ;;
    esac
  done

  [[ -n $dburl ]] || die "setup: missing <dburl>"

  if lambda_enabled; then
    lambda_require_deps
    lambda_invoke "$(lambda_payload_simple setup "$dburl")"
    return
  fi

  if [[ $(db_has_migrations_table "$dburl") == t ]]; then
    log_info "migrations table already present"
    return 0
  fi

  db_exec "$dburl" "CREATE TABLE IF NOT EXISTS migrations (
    timestamp   text        PRIMARY KEY,
    description text        NOT NULL,
    applied_at  timestamptz NOT NULL DEFAULT now()
  );"
  log_info "created migrations table"
}
