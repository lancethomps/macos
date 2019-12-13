#!/usr/bin/env bash
shopt -s expand_aliases; set -o errtrace
S="${BASH_SOURCE[0]}"; while [ -h "$S" ]; do D="$( cd -P "$( dirname "$S" )" && pwd )"; S="$(readlink "$S")"; [[ $S != /* ]] && S="$D/$S"; done; _SCRIPT_DIR="$( cd -P "$( dirname "$S" )" && pwd )"; unset S D
LAUNCHD_CONFIG_HOME="$(grealpath "$_SCRIPT_DIR/../config")"
load_as_daemon=false
load_as_global=false

while getopts ":i:s:Ddghv" opt; do case ${opt} in
  d) debug_mode=true ;;
  D) load_as_daemon=true ;;
  g) load_as_global=true ;;
  h) show_help_message=true ;;
  i) LAUNCHD_SCRIPT_ID="${OPTARG}" ;;
  s) LAUNCHD_SCRIPT_PATH="${OPTARG}" ;;
  v) verbose=true ;;
esac; done

if [ -z "$LAUNCHD_SCRIPT_ID" ]; then
  echo "You need to pass the -i arg"
  exit 1
fi
if [ -z "$LAUNCHD_SCRIPT_PATH" ]; then
  echo "You need to pass the -s arg"
  exit 1
fi
LAUNCHD_FILE="com.github.lancethomps.$LAUNCHD_SCRIPT_ID.plist"

function confirm () {
  read -r -p "${1:-Are you sure?}"$'\n'"[y/n]> " response
  case $response in
    [yY][eE][sS]|[yY]|"") true ;;
    [nN][oO]|[nN]) false ;;
    *) echo "Incorrect value entered... Try again."; confirm "$@" ;;
  esac
}
function replace_contents_with_env_vars () {
  [ -t 0 ] && contents="$1" && shift || contents=$(cat)
  local sed_cmd='sed -E'
  local has_vars=false
  local found_vars='@'
  local var_name
  for found_var in $(echo "$contents" | command grep -ioE '\$\{([a-zA-Z_]+)\}'); do
    if [[ "$found_vars" == *"@$found_var@"* ]]; then
      continue
    else
      found_vars="$found_vars$found_var@"
    fi
    has_vars=true
    local var_name=$(echo "$found_var" | tr -d '${}')
    local var_val=$(echo "${!var_name}" | sed -e 's/[\/&]/\\&/g')
    sed_cmd="$sed_cmd -e 's/\\\$\\{$var_name\\}/$var_val/g'"
  done
  if [ "$has_vars" == "true" ]; then
    echo "$contents" | eval "$sed_cmd"
  else
    echo "$contents"
  fi
}

launchd_path=""
launchd_type=""
if [ "$load_as_global" == "true" ]; then
  launchd_path="/Library"
else
  launchd_path="$HOME/Library"
fi
if [ "$load_as_daemon" == "true" ]; then
  launchd_type="LaunchDaemons"
else
  launchd_type="LaunchAgents"
fi

launchd_out="$launchd_path/$launchd_type/$LAUNCHD_FILE"

temp_config="$(mktemp -d)/$LAUNCHD_FILE"
echo "LaunchDaemon config is below..."
echo
cat "$LAUNCHD_CONFIG_HOME/$LAUNCHD_FILE" | replace_contents_with_env_vars | tee "$temp_config"
echo

if ! confirm "Load to $launchd_out?"; then
  exit 1
fi

LOG_FILE="$HOME/Library/Logs/com.github.lancethomps.launchd.log"
if ! test -f "$LOG_FILE"; then
  touch "$LOG_FILE"
fi

if [ "$load_as_global" == "true" ]; then
  sudo launchctl unload "$launchd_out" >/dev/null 2>&1
  sudo cp "$temp_config" "$launchd_out" || exit 1
  sudo launchctl load "$launchd_out"
else
  launchctl unload "$launchd_out" >/dev/null 2>&1
  cp "$temp_config" "$launchd_out" || exit 1
  launchctl load "$launchd_out"
fi
