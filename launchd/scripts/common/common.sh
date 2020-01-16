#!/usr/bin/env bash

if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root!"
  exit 1
fi

source "$_SCRIPT_DIR/common/common_non_root.sh"

function exec_as_user_without_prefix () {
  sudo -u "$current_user" "$@"
}
function exec_as_user () {
  sudo -u "$current_user" "$@" 2>&1 | sed "s/^/$(get_timestamp) \($SS_ID\) DEBUG /"
  return "${PIPESTATUS[0]}"
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
