#!/bin/sh
. "$(dirname $0)/env.sh"

cd "$packages_dir"
flutter create --template=package "$package_name"