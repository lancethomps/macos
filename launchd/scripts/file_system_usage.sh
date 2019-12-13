#!/usr/bin/env bash
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; _SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"; unset S D
set -e
set -o errtrace
SS_ID="FileSystemUsage"

source "$_SCRIPT_DIR/common/common.sh"
OUT_DIR="$SS_USER_HOME/.logs/fs"

if ! test -d "$OUT_DIR"; then
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
function add_dir_if_exists_except () {
  local subdir
  if test -d "$1"; then
    for subdir in "$1/"*; do
      if test -d "$subdir" && ! echo "$subdir" | grep -qE "$2"; then
        log_debug "Adding to scanned directories: $subdir"
        if test -z "$fg_dirs"; then
          fg_dirs="$subdir"
        else
          fg_dirs="$fg_dirs $subdir"
        fi
      fi
    done
  fi
  return 0
}

add_dir_if_exists_except '/private/var/folders' '/private/var/folders/zz'
add_dir_if_exists_except '/private/var' '/private/var/folders'
add_dir_if_exists '/Applications'
add_dir_if_exists '/Library'
add_dir_if_exists '/opt'
add_dir_if_exists_except '/System' '/System/Volumes'
add_dir_if_exists '/Users'
add_dir_if_exists '/usr'
add_dir_if_exists '/private/etc'
add_dir_if_exists '/private/tmp'

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

_py_code=$(
  cat << EOF
from typing import Match

from ltpylib import files

sizes = [
  (1000000.0, "MB"),
  (1000000000.0, "GB"),
]

def repl(match: Match) -> str:
  size: float = float(match.group(1).replace(',', ''))
  div: float = None
  desc: str = None
  for size_pair in sizes:
    if div is None:
      div = size_pair[0]
      desc = size_pair[1]
      continue

    if size > size_pair[0]:
      div = size_pair[0]
      desc = size_pair[1]

  size = float(size) / div
  return "(" + "{0:,.2f}".format(size) + " " + desc

files.replace_matches_in_file("$OUT_FILE", r"\(([0-9,]+) bytes", repl)
EOF
)

exec_as_user_without_prefix "$SS_USER_HOME/.pyenv/shims/python3" -c "$_py_code"

push_to_git_repo "$OUT_DIR"
log_finished
