#!/usr/bin/env bash

export TZ_OFFSET=$(python -c 'import time;import sys;sys.stdout.write(time.strftime("%z"))')
function get_timestamp () {
  echo $(python -c 'from datetime import datetime;import sys;sys.stdout.write(datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]);')" $TZ_OFFSET"
}
export run_time=$(get_timestamp)

function exec_with_log_prefix () {
  eval "$@" | sed "s/^/$(get_timestamp) \($SS_ID\) DEBUG /"
  return "${PIPESTATUS[0]}"
}

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root!"
  exit 1
fi
if ! current_user=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }'); then
  exec_with_log_prefix echo 'Problem retrieving the currently logged in user! Exiting after running failed command again below...'
  /bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }' | sed "s/^/$(get_timestamp) \($SS_ID\) DEBUG /"
  exit 1
fi
export SS_USER_HOME="/Users/$current_user"

function exec_as_user_without_prefix () {
  sudo -u "$current_user" "$@"
}
function exec_as_user () {
  sudo -u "$current_user" "$@" 2>&1 | sed "s/^/$(get_timestamp) \($SS_ID\) DEBUG /"
  return "${PIPESTATUS[0]}"
}
function log_debug () {
  echo "$(get_timestamp) ($SS_ID) DEBUG $@"
}
function log_starting () {
  log_debug "Starting $SS_ID..."
}
function log_finished () {
  log_debug "Finished $SS_ID"
}
function find_command_loc () {
  if [ -e "/usr/local/bin/$1" ]; then
    echo "/usr/local/bin/$1"
  else
    echo "/usr/bin/$1"
  fi
}

export GIT_LOC="$(find_command_loc git)"

function commit_to_git_repo () {
  local commit_type
  if [ ! -z "$3" ]; then
    commit_type=" $3"
  fi
  local commit_msg="$SS_ID Auto Log$commit_type: $run_time"
  local repo_status=$(exec_as_user_without_prefix ${GIT_LOC} -C "$1" status --porcelain)
  if [ -z "$2" ]; then
    if [ -z "$repo_status" ]; then
      return 0
    fi
  else
    local status_for_subdir=$(echo "$repo_status" | grep "$2")
    if [ -z "$status_for_subdir" ]; then
      return 0
    fi
  fi
  exec_as_user ${GIT_LOC} -C "$1" add "${2:-.}"
  log_debug 'Committing to git repo...'
  exec_as_user ${GIT_LOC} -C "$1" commit -m "$commit_msg"
}
function pull_from_git_repo () {
  if [ -d "$1/.git" ]; then
    if ! exec_as_user ${GIT_LOC} -C "$1" pull; then
      exec_as_user ${GIT_LOC} -C "$1" merge --abort
    fi
  fi
  return 0
}
function push_to_git_repo () {
  # Add to git repo and push
  if [ -d "$1/.git" ]; then
    commit_to_git_repo "$1"
    exec_as_user ${GIT_LOC} -C "$1" push
  fi
}
