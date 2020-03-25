#!/usr/bin/env bash
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; _SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"; unset S D
set -o errexit -o errtrace
SS_ID="FileSystemLog"

source "$_SCRIPT_DIR/common/launchd_common.sh"
OUT_DIR="$SS_USER_HOME/.logs/fs"

FIND_LOC="$(find_command_loc find)"

if [ ! -d "$OUT_DIR" ]; then
  exec_as_user mkdir -pv "$OUT_DIR"
fi

log_starting
pull_from_git_repo "$OUT_DIR"

function log_getting_snapshot() {
  log_debug "Getting snapshot: $*"
}
function find_with_default_args () {
  local base="$1"; shift
  ${FIND_LOC} -H "$base" \( -type l -o -type f \) ! -path '*.DS_Store' ! -path '*/.git/*' "$@" -ls
}

# Log any modified files in critical directories
log_getting_snapshot "$SS_USER_HOME"
find_with_default_args "$SS_USER_HOME" -regextype 'posix-extended' -regex "$SS_USER_HOME"'/([0-9a-zA-Z_\-\. ]+|bin.*|.dotfiles.*)' > "$OUT_DIR/home.log"

log_getting_snapshot '/etc'
find_with_default_args /etc > "$OUT_DIR/etc.log"

log_getting_snapshot '/usr'
find_with_default_args /usr -regextype 'posix-extended' -regex '/usr/([0-9a-zA-Z_\-\. ]+|bin.*|include.*|lib.*|libexec.*|sbin.*|local/bin/.*|local/etc/.*|local/jamf/.*|local/opt/.*)' > "$OUT_DIR/usr.log"

log_getting_snapshot '/opt'
find_with_default_args /opt -regextype 'posix-extended' -regex '/opt/([0-9a-zA-Z_\-\. ]+|\.bluecoat-ua.*|cisco.*)' ! -path '*WebSecurityPhoneHome.cef.temp' > "$OUT_DIR/opt.log"

log_getting_snapshot '/Library'
find_with_default_args /Library -regextype 'posix-extended' -regex '/Library/([0-9a-zA-Z_\-\. ]+|Preferences.*)' ! -path '*/Caches' ! -path '*/Logs' > "$OUT_DIR/lib.log"

log_getting_snapshot "$SS_USER_HOME/Library"
find_with_default_args "$SS_USER_HOME/Library" -regextype 'posix-extended' -regex "$SS_USER_HOME"'/Library/([0-9a-zA-Z_\-\. ]+|Preferences.*)' ! -path '*/Caches' ! -path '*/Logs' > "$OUT_DIR/lib.home.log"

# Log system settings
log_debug 'Logging defaults'
/usr/bin/defaults read > "$OUT_DIR/defaults.log"
exec_as_user /usr/bin/defaults read > "$OUT_DIR/defaults.user.log"
log_debug 'Logging pmset'
/usr/bin/pmset -g custom > "$OUT_DIR/pmset.log"
log_debug 'Logging kextstat'
/usr/sbin/kextstat > "$OUT_DIR/kextstat.log"
log_debug 'Logging sysctl'
/usr/sbin/sysctl -a | /usr/bin/sort > "$OUT_DIR/sysctl.log"

push_to_git_repo "$OUT_DIR"
log_finished
