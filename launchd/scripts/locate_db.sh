#!/usr/bin/env bash
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; _SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"; unset S D
set -e
set -o errtrace
SS_ID="LocateDb"

source "$_SCRIPT_DIR/common/common.sh"

log_starting

export LOCATE_PATH="$SS_USER_HOME/tmp/locate.database"

/usr/local/bin/gupdatedb \
	--output="$LOCATE_PATH" \
	--prunepaths='/tmp /var'

log_finished
