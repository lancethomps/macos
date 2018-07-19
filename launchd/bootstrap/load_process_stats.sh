#!/usr/bin/env bash
set -e
set -o errtrace
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"

LAUNCHD_SCRIPTS_HOME=$(grealpath "$SCRIPT_DIR/../scripts")
"$SCRIPT_DIR/_load_launchd.sh" -i 'ProcessStats' -s "$LAUNCHD_SCRIPTS_HOME/process_stats.py"
