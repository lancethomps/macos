#!/usr/bin/env bash
set -e
set -o errtrace
SS_ID="FileSystemLog"

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

function log_getting_snapshot() {
	log_debug "Getting snapshot: $@"
}
function find_with_default_args () {
	local base="$1"; shift
	/usr/local/bin/find -H "$base" \( -type l -o -type f \) ! -path '*.DS_Store' ! -path '*/.git/*' "$@" -ls
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

# Add Preferences
## Copy macOS preferences

## Add Eclipse settings
prefs_loc="$SS_USER_HOME/prefs"
if [ -d "$prefs_loc" ]; then
	log_debug 'Adding preferences...'
	commit_prefs=false
	prefs_ec="$prefs_loc/eclipse"
	exec_with_log_prefix mkdir -pv "$prefs_ec"
	ec_home="/Users/Shared/workspace"
	ec_working_sets="$ec_home/.metadata/.plugins/org.eclipse.ui.workbench/workingsets.xml"
	if [ -f "$ec_working_sets" ]; then
		log_debug "Copying Eclipse working sets: $ec_working_sets"
		cp "$ec_working_sets" "$prefs_ec/workingsets.xml" && commit_prefs=true
	fi
	ec_features='/Applications/Eclipse.app/Contents/Eclipse/features'
	if [ -d "$ec_features" ]; then
		transferred_files=$(/usr/local/bin/rsync -ru --info=name --prune-empty-dirs --delete --filter='+ */' --filter='+ feature.properties' --filter='+ feature.xml' --filter='- *' "$ec_features" "$prefs_loc/eclipse/")
		if [ ! -z "$transferred_files" ]; then
			log_debug "Updated Eclipse feature files: $transferred_files"
			commit_prefs=true
		fi
	fi
	if [ "$commit_prefs" == "true" ]; then
		commit_to_git_repo "$prefs_loc" "eclipse" "Eclipse Settings"
	fi
fi

# Add to git repo and push
commit_to_git_repo "$OUT_DIR"
exec_as_user /usr/local/bin/git -C "$OUT_DIR" push
log_finished
