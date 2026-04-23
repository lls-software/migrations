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
    apply)
      shift
      cmd_apply "$@"
      ;;
    init)
      shift
      cmd_init "$@"
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
  init    [--dir <path>]  Create migrations/ dir and .migrationsrc in the current repo
  setup   <dburl>         Create the migrations tracking table on the target database
  new     [--no-transaction] <description>
                          Create a new timestamped migration file
  status  [--history] <dburl>
                          Show pending migrations (and, with --history, all applied rows)
  apply   <dburl>         Apply all pending migrations in timestamp order
  mark    <dburl> (<timestamp> | --all) [--description <text>] [--force]
                          Record migration(s) as applied without running
  unmark  <dburl> <timestamp>
                          Remove a migration's row from the tracking table
EOF
}
