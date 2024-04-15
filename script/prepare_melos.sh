#!/bin/sh
. "$(dirname $0)/env.sh"

# 检查是否安装了 melos 命令
if ! command -v melos > /dev/null; then
    echo "melos is not installed. Installing..."
    dart pub global activate melos
    export PATH="$PATH":"$HOME/.pub-cache/bin"
fi
