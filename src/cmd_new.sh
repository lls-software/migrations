# shellcheck shell=bash
cmd_new() {
  local dir=./migrations
  local description=''
  local directive=''

  while (( $# )); do
    case $1 in
      --dir)
        dir=${2-}
        [[ -n $dir ]] || die "new: --dir requires a path"
        shift 2
        ;;
      --dir=*)
        dir=${1#--dir=}
        shift
        ;;
      --no-transaction)
        directive=no-transaction
        shift
        ;;
      --)
        shift
        description=${1-}
        break
        ;;
      -*)
        die "new: unknown option: $1"
        ;;
      *)
        description=$1
        shift
        break
        ;;
    esac
  done

  [[ -n $description ]] || die "new: missing <description>"
  [[ -d $dir ]] || die "migrations directory not found: $dir"

  local slug
  slug=$(slugify "$description")
  [[ -n $slug ]] || die "new: description has no slug-able characters"

  fs_new_migration "$dir" "$(timestamp_now)" "$slug" "$description" "$directive"
}
