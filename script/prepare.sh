#!/bin/sh
. "$(dirname $0)/env.sh"

. $script_dir/prepare_melos.sh
cd "$ROOT"
melos bootstrap
