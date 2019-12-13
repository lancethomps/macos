#!/usr/bin/env bash
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; _SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"; unset S D
set -e
set -o errtrace
SS_ID="FileSystemUsage"

source "$_SCRIPT_DIR/common/common.sh"
OUT_DIR="$SS_USER_HOME/.logs/fs"

if [ ! -d "$OUT_DIR" ]; then
  exec_as_user mkdir -pv "$OUT_DIR"
fi

log_starting
pull_from_git_repo "$OUT_DIR"

fg_dirs=""
function add_dir_if_exists () {
  if test -d "$1"; then
    log_debug "Adding to scanned directories: $1"
    if test -z "$fg_dirs"; then
      fg_dirs="$1"
    else
      fg_dirs="$fg_dirs $1"
    fi
  fi
  return 0
}

add_dir_if_exists '/Applications'
add_dir_if_exists '/Library'
add_dir_if_exists '/opt'
add_dir_if_exists '/System'
add_dir_if_exists '/Users'
add_dir_if_exists '/usr'
add_dir_if_exists '/private/etc'
add_dir_if_exists '/private/tmp'
add_dir_if_exists '/private/var'

FG_FILES_OUT="$(exec_as_user_without_prefix mktemp)"
log_debug "Generating files list to: $FG_FILES_OUT"
/usr/local/bin/flamegraph_files.pl $fg_dirs > "$FG_FILES_OUT"

OUT_FILE="$OUT_DIR/$SS_ID.svg"
if ! test -f "$OUT_FILE"; then
  exec_as_user touch "$OUT_FILE"
fi
log_debug "Generating graph and outputting to: $OUT_FILE"
exec_as_user_without_prefix /usr/local/bin/flamegraph.pl \
  --hash \
  --width=1600 \
  --height=32 \
  --colors='hot' \
  --title="File System Usage: $(date)" \
  --countname=bytes \
  "$FG_FILES_OUT" > "$OUT_FILE"

rm "$FG_FILES_OUT"

push_to_git_repo "$OUT_DIR"
log_finished
