#!/bin/sh
. "$(dirname $0)/env.sh"

cd "$apps_dir"
flutter create --template skeleton --org "$organization" --project-name "$app_name" "$app_name"