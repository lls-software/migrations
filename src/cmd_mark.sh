# shellcheck shell=bash
cmd_mark() {
  local dir=./migrations
  local dburl=''
  local ts=''
  local description=''
  local description_set=''
  local force=''

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
