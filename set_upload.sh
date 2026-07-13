#!/usr/bin/env sh
set -eu

if [ "$#" -ne 1 ]; then
	echo "Usage: ./set_upload.sh 0|1"
	exit 2
fi

case "$1" in
	1|true|TRUE|yes|YES|on|ON)
		value="1"
		;;
	0|false|FALSE|no|NO|off|OFF)
		value="0"
		;;
	*)
		echo "Usage: ./set_upload.sh 0|1"
		exit 2
		;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
flag_path="$script_dir/matchmaker/upload_agent_enabled.txt"

printf "%s\n" "$value" > "$flag_path"

if [ "$value" = "1" ]; then
	echo "Agent upload mode: ON (players run opponent-uploaded agents)"
else
	echo "Agent upload mode: OFF (players run their own selected agents)"
fi
