#!/usr/bin/env bash

export TZ_OFFSET="$(python -c 'import time;import sys;sys.stdout.write(time.strftime("%z"))')"
function get_timestamp () {
  echo "$(python -c 'from datetime import datetime;import sys;sys.stdout.write(datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]);') $TZ_OFFSET"
}
export run_time="$(get_timestamp)"

function exec_with_log_prefix () {
  eval "$@" | sed "s/^/$(get_timestamp) \($SS_ID\) DEBUG /"
  return "${PIPESTATUS[0]}"
}
function log_debug () {
  echo "$(get_timestamp) ($SS_ID) DEBUG $*"
}
function log_starting () {
  log_debug "Starting $SS_ID..."
}
function log_finished () {
  log_debug "Finished $SS_ID"
}

if ! current_user="$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }')"; then
  exec_with_log_prefix echo 'Problem retrieving the currently logged in user! Exiting after running failed command again below...'
  /bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }' | sed "s/^/$(get_timestamp) \($SS_ID\) DEBUG /"
  exit 1
fi
export SS_USER_HOME="/Users/$current_user"
# log_debug "SS_USER_HOME=${SS_USER_HOME}"
