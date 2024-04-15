#!/bin/sh
. "$(dirname $0)/env.sh"

# 检查并创建目录
if [ ! -d "$apps_dir" ]; then
    echo "Directory $apps_dir does not exist. Creating..."
    mkdir -p "$apps_dir"
fi
cd "$apps_dir"
flutter create --template skeleton --org "$organization" --project-name "$app_name" "$app_name"