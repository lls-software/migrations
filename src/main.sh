# shellcheck shell=bash
main() {
  dispatch "$@"
}

dispatch() {
  local cmd=${1-}
  case $cmd in
    --version|-v)
      print_version
      ;;
    --help|-h)
      print_help
      ;;
    '')
      print_help >&2
      exit 1
      ;;
    setup)
      shift
      cmd_setup "$@"
      ;;
    new)
      shift
      cmd_new "$@"
      ;;
    init|status|apply)
      log_error "command not yet implemented: $cmd"
      exit 1
      ;;
    *)
      log_error "unknown command: $cmd"
      print_help >&2
      exit 1
      ;;
  esac
}

print_version() {
  echo "migrations.sh $VERSION"
}

print_help() {
  cat <<EOF
migrations.sh — SQL-first Postgres migrations

Usage:
  migrations.sh <command> [args]
  migrations.sh --version | -v
  migrations.sh --help    | -h

Commands:
  init                    Scaffold migrations/, schema.sql, and config in the current repo
  setup   <dburl>         Create the migrations tracking table on the target database
  new     <description>   Create a new timestamped migration file
  status  <dburl>         Show pending migrations and drift
  apply   <dburl>         Apply all pending migrations in timestamp order
EOF
}
