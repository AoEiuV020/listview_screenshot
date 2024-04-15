#!/bin/sh
. "$(dirname $0)/env.sh"

# 检查并创建目录
if [ ! -d "$packages_dir" ]; then
    echo "Directory $packages_dir does not exist. Creating..."
    mkdir -p "$packages_dir"
fi
cd "$packages_dir"
flutter create --template=package "$package_name"