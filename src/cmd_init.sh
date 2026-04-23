# shellcheck shell=bash
cmd_init() {
  local target_dir=./migrations

  while (( $# )); do
    case $1 in
      --dir)
        target_dir=${2?}
        shift 2
        ;;
      --dir=*)
        target_dir=${1#--dir=}
        shift
        ;;
      -*)
        die "init: unknown option: $1"
        ;;
      *)
        target_dir=$1
        shift
        ;;
    esac
  done

  if [[ -f .migrationsrc ]]; then
    die '.migrationsrc already exists; remove it first to re-init'
  fi

  mkdir -p -- "$target_dir"
  printf 'dir=%s\n' "$target_dir" > .migrationsrc
  log_info "created $target_dir/ and .migrationsrc"
  log_info 'run: migrations.sh setup <dburl>'
}