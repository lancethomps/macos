#!/usr/bin/env bash
set -e
set -o errtrace
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; _SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"; unset S D

if ! test -e '/usr/local/bin/flamegraph.pl' || ! test -e '/usr/local/bin/flamegraph_files.pl'; then
	echo 'FlameGraph binaries not found, please clone this repo and run the below: https://github.com/brendangregg/FlameGraph'
	echo 'ln -s <cloned_repo>/files.pl /usr/local/bin/flamegraph_files.pl'
	echo 'ln -s <cloned_repo>/flamegraph.pl /usr/local/bin/flamegraph.pl'
	exit 1
fi

LAUNCHD_SCRIPTS_HOME="$(grealpath "$_SCRIPT_DIR/../scripts")"
"$_SCRIPT_DIR/_load_launchd.sh" -i 'FileSystemUsage' -s "$LAUNCHD_SCRIPTS_HOME/file_system_usage.sh" -gD
