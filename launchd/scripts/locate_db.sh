#!/usr/bin/env bash
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; _SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"; unset S D
set -e
set -o errtrace
SS_ID="LocateDb"

source "$_SCRIPT_DIR/common/common_non_root.sh"

log_starting

export LOCATE_PATH="$SS_USER_HOME/locate.database"
export _LOCALPATHS=()

function add_dir_if_exists () {
  if test -d "$1"; then
    log_debug "Adding to scanned directories: $1"
    _LOCALPATHS+=("$1")
  fi
  return 0
}
function add_dir_if_exists_except () {
  local subdir
  if test -d "$1"; then
    for subdir in "$1/"*; do
      if test -d "$subdir" && ! echo "$subdir" | grep -qE "$2"; then
        log_debug "Adding to scanned directories: $subdir"
        _LOCALPATHS+=("$subdir")
      fi
    done
  fi
  return 0
}

add_dir_if_exists '/Applications'
add_dir_if_exists '/bin'
add_dir_if_exists '/etc'
add_dir_if_exists '/Library'
add_dir_if_exists '/opt'
add_dir_if_exists '/sbin'
# add_dir_if_exists_except '/System' '(/System/Volumes)'
add_dir_if_exists '/Users/Shared'
add_dir_if_exists "$SS_USER_HOME"
add_dir_if_exists '/usr'

/usr/local/bin/gupdatedb \
  --output="$LOCATE_PATH" \
  --localpaths="${_LOCALPATHS[*]}" \
  --prunepaths='/tmp /var'

log_finished
