#!/usr/bin/env bash
set -e
set -o errtrace
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"

LAUNCHD_SCRIPTS_HOME=$(grealpath "$SCRIPT_DIR/../scripts")
"$SCRIPT_DIR/_load_launchd.sh" -i 'PrefsLog' -s "$LAUNCHD_SCRIPTS_HOME/prefs_log.sh" -gD
