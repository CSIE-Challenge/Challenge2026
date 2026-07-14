#!/usr/bin/env sh
set -eu
./set_upload.sh 0
exec dumb-init -- node matchmaker/server.js
