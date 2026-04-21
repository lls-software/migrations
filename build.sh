#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# Concatenation order: utilities first, commands, dispatcher last.
SRC_FILES=(
  src/util.sh
  src/config.sh
  src/db.sh
  src/fs.sh
  src/cmd_init.sh
  src/cmd_setup.sh
  src/cmd_new.sh
  src/cmd_status.sh
  src/cmd_apply.sh
  src/main.sh
)

build() {
  local version
  version=$(<VERSION)
  local out=migrations.sh

  {
    echo '#!/usr/bin/env bash'
    echo 'set -euo pipefail'
    echo
    printf 'VERSION="%s"\n' "$version"
    echo
    sed '/^source /d' "${SRC_FILES[@]}"
    echo
    echo 'main "$@"'
  } > "$out"

  chmod +x "$out"
}

build "$@"
