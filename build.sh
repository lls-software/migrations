#!/usr/bin/env bash
set -euo pipefail

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
  :  # TODO: concat SRC_FILES, strip `^source ` lines, prepend shebang +
     # `set -euo pipefail` + VERSION constant, append `main "$@"`, chmod +x.
}

build "$@"
