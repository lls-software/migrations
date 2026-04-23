# shellcheck shell=bash
cmd_mark() {
  local dburl=''
  local dir=''
  dir=$(config_get_dir)
  local ts=''
  local description=''
  local description_set=''
  local force=''
  local all=''

  while (( $# )); do
    case $1 in
      --dir)
        dir=${2-}
        [[ -n $dir ]] || die "mark: --dir requires a path"
        shift 2
        ;;
      --dir=*)
        dir=${1#--dir=}
        shift
        ;;
      --description)
        description=${2-}
        description_set=1
        shift 2
        ;;
      --description=*)
        description=${1#--description=}
        description_set=1
        shift
        ;;
      --force)
        force=1
        shift
        ;;
      --all)
        all=1
        shift
        ;;
      -*)
        die "mark: unknown option: $1"
        ;;
      *)
        if [[ -z $dburl ]]; then
          dburl=$1
        elif [[ -z $ts ]]; then
          ts=$1
        else
          die "mark: unexpected argument: $1"
        fi
        shift
        ;;
    esac
  done

  [[ -n $dburl ]] || die "mark: missing <dburl>"

  if [[ -n $all ]]; then
    [[ -z $ts ]] || die "mark: --all does not take a timestamp"
    [[ -z $description_set ]] || die "mark: --all does not accept --description"
    [[ -z $force ]] || die "mark: --all does not accept --force"
    cmd_mark_all "$dburl" "$dir"
    return
  fi

  [[ -n $ts ]] || die "mark: missing <timestamp>"
  [[ $ts =~ ^[0-9]{10}$ || $ts =~ ^[0-9]{14}$ ]] \
    || die "mark: invalid timestamp: $ts"

  if [[ -z $force && ! -d $dir ]]; then
    die "migrations directory not found: $dir (use --force to skip file lookup)"
  fi

  if [[ $(db_has_migrations_table "$dburl") != t ]]; then
    die "migrations table not found; run: migrations.sh setup <dburl>"
  fi

  local file_desc
  if file_desc=$(fs_find_migration "$dir" "$ts"); then
    [[ -n $description_set ]] || description=$file_desc
  else
    [[ -n $force ]] \
      || die "mark: no file for $ts in $dir (use --force to override)"
  fi

  db_insert_migration "$dburl" "$ts" "$description"
  log_info "marked $ts as applied"
}

cmd_mark_all() {
  local dburl=$1 dir=$2

  [[ -d $dir ]] || die "migrations directory not found: $dir"

  if [[ $(db_has_migrations_table "$dburl") != t ]]; then
    die "migrations table not found; run: migrations.sh setup <dburl>"
  fi

  local files
  files=$(fs_list_migrations "$dir")
  if [[ -z $files ]]; then
    printf 'no migrations in %s\n' "$dir"
    return 0
  fi

  local total marked inserted_count skipped ts
  total=$(printf '%s\n' "$files" | grep -c .)
  marked=$(printf '%s\n' "$files" | db_mark_missing "$dburl")
  if [[ -n $marked ]]; then
    while IFS= read -r ts; do
      [[ -n $ts ]] || continue
      log_info "marked $ts as applied"
    done <<< "$marked"
    inserted_count=$(printf '%s\n' "$marked" | grep -c .)
  else
    inserted_count=0
  fi

  skipped=$(( total - inserted_count ))
  if (( skipped > 0 )); then
    log_info "skipped $skipped already-marked migration(s)"
  fi
}
