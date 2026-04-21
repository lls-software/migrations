# shellcheck shell=bash
cmd_apply() {
  local dir=./migrations
  local dburl=''

  while (( $# )); do
    case $1 in
      --dir)
        dir=${2-}
        [[ -n $dir ]] || die "apply: --dir requires a path"
        shift 2
        ;;
      --dir=*)
        dir=${1#--dir=}
        shift
        ;;
      -*)
        die "apply: unknown option: $1"
        ;;
      *)
        [[ -z $dburl ]] || die "apply: unexpected argument: $1"
        dburl=$1
        shift
        ;;
    esac
  done

  [[ -n $dburl ]] || die "apply: missing <dburl>"
  [[ -d $dir ]]   || die "migrations directory not found: $dir"

  if [[ $(db_has_migrations_table "$dburl") != t ]]; then
    die "migrations table not found; run: migrations.sh setup <dburl>"
  fi

  local files applied_subset line ts desc file
  files=$(fs_list_migrations "$dir")
  if [[ -z $files ]]; then
    printf 'no migrations in %s\n' "$dir"
    return 0
  fi

  applied_subset=$(printf '%s\n' "$files" \
    | awk -F'|' '$1 ~ /^[0-9]+$/ && (length($1)==10 || length($1)==14) {print $1}' \
    | db_applied_subset "$dburl")

  declare -A applied=()
  if [[ -n $applied_subset ]]; then
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      applied[${line%%|*}]=1
    done <<< "$applied_subset"
  fi

  local pending=() count=0
  while IFS= read -r line; do
    [[ -n $line ]] || continue
    ts=${line%%|*}
    [[ -n ${applied[$ts]-} ]] && continue
    pending+=("$line")
  done <<< "$files"

  if (( ${#pending[@]} == 0 )); then
    log_info "no pending migrations"
    return 0
  fi

  for line in "${pending[@]}"; do
    ts=${line%%|*}
    desc=${line#*|}
    file=$(fs_find_migration_path "$dir" "$ts") \
      || die "apply: file vanished for $ts"
    log_info "applying $ts $desc"
    db_apply_file "$dburl" "$file" "$ts" "$desc" \
      || die "failed to apply $ts"
    (( count++ ))
  done

  log_info "applied $count migration(s)"
}
