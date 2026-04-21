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
    status)
      shift
      cmd_status "$@"
      ;;
    mark)
      shift
      cmd_mark "$@"
      ;;
    unmark)
      shift
      cmd_unmark "$@"
      ;;
    init|apply)
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
  status  [--history] <dburl>
                          Show pending migrations (and, with --history, all applied rows)
  apply   <dburl>         Apply all pending migrations in timestamp order
  mark    <dburl> <timestamp> [--description <text>] [--force]
                          Record a migration as applied without running it
  unmark  <dburl> <timestamp>
                          Remove a migration's row from the tracking table
EOF
}
