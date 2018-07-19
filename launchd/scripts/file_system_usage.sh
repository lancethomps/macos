#!/usr/bin/env bash
set -e
set -o errtrace
SS_ID="FileSystemUsage"

TZ_OFFSET=$(python -c 'import time;import sys;sys.stdout.write(time.strftime("%z"))')
function get_timestamp () {
	echo $(python -c 'from datetime import datetime;import sys;sys.stdout.write(datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]);')" $TZ_OFFSET"
}
run_time=$(get_timestamp)

if [ "$(id -u)" -ne 0 ]; then
	echo "This script must be run as root!"
	exit 1
fi
if ! current_user=$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }'); then
	exec_with_log_prefix echo 'Problem retrieving the currently logged in user! Exiting after running failed command again below...'
	/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }' | sed "s/^/$(get_timestamp) \($SS_ID\) DEBUG /"
	exit 1
fi
SS_USER_HOME="/Users/$current_user"

function exec_with_log_prefix () {
	eval "$@" | sed "s/^/$(get_timestamp) \($SS_ID\) DEBUG /"
}
function exec_as_user_without_prefix () {
	sudo -u "$current_user" "$@"
}
function exec_as_user () {
	sudo -u "$current_user" "$@" 2>&1 | sed "s/^/$(get_timestamp) \($SS_ID\) DEBUG /"
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

OUT_DIR="$SS_USER_HOME/.logs/fs"
if [ ! -d "$OUT_DIR" ]; then
	exec_as_user mkdir -pv "$OUT_DIR"
fi

function commit_to_git_repo () {
	local commit_type
	if [ ! -z "$3" ]; then
		commit_type=" $3"
	fi
	local commit_msg="$SS_ID Auto Log$commit_type: $run_time"
	local repo_status=$(exec_as_user_without_prefix /usr/local/bin/git -C "$1" status --porcelain)
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
	exec_as_user /usr/local/bin/git -C "$1" add "${2:-.}"
	log_debug 'Committing to git repo...'
	exec_as_user /usr/local/bin/git -C "$1" commit -m "$commit_msg"
}

log_starting

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
log_debug "Generating files list to $FG_FILES_OUT..."
/usr/local/bin/flamegraph_files.pl $fg_dirs > "$FG_FILES_OUT"

OUT_FILE="$OUT_DIR/$SS_ID.svg"
if ! test -f "$OUT_FILE"; then
	exec_as_user touch "$OUT_FILE"
fi
log_debug "Generating graph and outputting to $OUT_FILE..."
exec_as_user_without_prefix /usr/local/bin/flamegraph.pl \
	--hash \
	--width=1600 \
	--height=32 \
	--colors='hot' \
	--title="File System Usage: $(date)" \
	--countname=bytes \
	"$FG_FILES_OUT" > "$OUT_FILE"

rm "$FG_FILES_OUT"

commit_to_git_repo "$OUT_DIR"
exec_as_user /usr/local/bin/git -C "$OUT_DIR" push

log_finished
