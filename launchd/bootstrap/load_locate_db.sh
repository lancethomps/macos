#!/usr/bin/env bash
set -e
set -o errtrace
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; _SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"; unset S D

LAUNCHD_SCRIPTS_HOME="$(grealpath "$_SCRIPT_DIR/../scripts")"
"$_SCRIPT_DIR/_load_launchd.sh" -i 'LocateDb' -s "$LAUNCHD_SCRIPTS_HOME/locate_db.sh" -gD
