# shellcheck shell=bash
cmd_status() {
  local dburl=
  local dir=''
  dir=$(config_get_dir)
  local history=

  while (( $# )); do
    case $1 in
      --dir)
        dir=${2-}
        [[ -n $dir ]] || die "status: --dir requires a path"
        shift 2
        ;;
      --dir=*)
        dir=${1#--dir=}
        shift
        ;;
      --history)
        history=1
        shift
        ;;
      -*)
        die "status: unknown option: $1"
        ;;
      *)
        dburl=$1
        shift
        break
        ;;
    esac
  done

  [[ -n $dburl ]] || die "status: missing <dburl>"
  [[ -d $dir ]] || die "migrations directory not found: $dir"

  if [[ $(db_has_migrations_table "$dburl") != t ]]; then
    die "migrations table not found; run: migrations.sh setup <dburl>"
  fi

  local files applied all_applied=
  files=$(fs_list_migrations "$dir")
  applied=$(printf '%s\n' "$files" \
            | awk -F'|' '$1 ~ /^[0-9]+$/ && (length($1)==10 || length($1)==14) {print $1}' \
            | db_applied_subset "$dburl")
  if [[ -n $history ]]; then
    all_applied=$(db_list_applied "$dburl")
  fi

  status_render "$dir" "$files" "$applied" "$all_applied"
}

status_render() {
  local dir=$1 files=$2 applied=$3 all_applied=$4

  declare -A applied_desc=()
  declare -A file_set=()
  local ts desc line

  if [[ -n $applied ]]; then
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      ts=${line%%|*}
      desc=${line#*|}
      applied_desc[$ts]=$desc
    done <<< "$applied"
  fi

  local rows=
  if [[ -n $files ]]; then
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      ts=${line%%|*}
      desc=${line#*|}
      file_set[$ts]=1
      if [[ -n ${applied_desc[$ts]+x} ]]; then
        rows+=$(printf '%s\tapplied\t%s\n' "$ts" "${applied_desc[$ts]}")$'\n'
      else
        rows+=$(printf '%s\tpending\t%s\n' "$ts" "$desc")$'\n'
      fi
    done <<< "$files"
  fi

  if [[ -n $all_applied ]]; then
    while IFS= read -r line; do
      [[ -n $line ]] || continue
      ts=${line%%|*}
      desc=${line#*|}
      [[ -n ${file_set[$ts]-} ]] && continue
      rows+=$(printf '%s\tapplied\t%s\n' "$ts" "$desc")$'\n'
    done <<< "$all_applied"
  fi

  if [[ -z $rows ]]; then
    printf 'no migrations in %s\n' "$dir"
    return 0
  fi

  printf '%-14s  %-7s  %s\n' TIMESTAMP STATUS DESCRIPTION
  printf '%s' "$rows" | sort -k1,1 | while IFS=$'\t' read -r ts status desc; do
    printf '%-14s  %-7s  %s\n' "$ts" "$status" "$desc"
  done
}
