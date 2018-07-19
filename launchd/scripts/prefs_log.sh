#!/usr/bin/env bash
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"
set -e
set -o errtrace
SS_ID="PrefsLog"

source "$SCRIPT_DIR/common/common.sh"
OUT_DIR="$SS_USER_HOME/prefs"

RSYNC_LOC="$(find_command_loc rsync)"

if [ ! -d "$OUT_DIR" ]; then
	echo "Prefs output directory does not exist: $OUT_DIR"
	exit 1
fi

log_starting
pull_from_git_repo "$OUT_DIR"

# Add Preferences
## Copy macOS preferences

## Add Eclipse settings
function add_eclipse_settings () {
	local ec_home="$1"
	local ec_id="$2"
	if [ -d "$ec_home" ]; then
		log_debug 'Adding Eclipse preferences...'
		commit_prefs=false
		prefs_ec="$OUT_DIR/eclipse/$ec_id"
		exec_with_log_prefix mkdir -pv "$prefs_ec"
		ec_working_sets="$ec_home/.metadata/.plugins/org.eclipse.ui.workbench/workingsets.xml"
		if [ -f "$ec_working_sets" ]; then
			log_debug "Copying Eclipse working sets: $ec_working_sets"
			cp "$ec_working_sets" "$prefs_ec/workingsets.xml" && commit_prefs=true
		fi
		ec_features='/Applications/Eclipse.app/Contents/Eclipse/features'
		if [ -d "$ec_features" ]; then
			transferred_files=$(${RSYNC_LOC} -ru --info=name --prune-empty-dirs --delete --filter='+ */' --filter='+ feature.properties' --filter='+ feature.xml' --filter='- *' "$ec_features" "$prefs_ec/")
			if [ ! -z "$transferred_files" ]; then
				log_debug "Updated Eclipse feature files: $transferred_files"
				commit_prefs=true
			fi
		fi
		if [ -d "$OUT_DIR/.git" ] && [ "$commit_prefs" == "true" ]; then
			commit_to_git_repo "$OUT_DIR" "eclipse" "Eclipse Settings"
		fi
	fi
}
add_eclipse_settings "/Users/Shared/workspace" 'blk'
add_eclipse_settings "$SS_USER_HOME/eclipse-workspace" 'personal'

push_to_git_repo "$OUT_DIR"
log_finished
