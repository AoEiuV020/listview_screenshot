#!/bin/sh
# 打印最新版本的更新日志，
# 关键是以markdown的格式加粗第一行，
# 可选参数一个，指定版本打印更新日志，
set -e
cd $(dirname $0)
versionName=$1
versionName=${versionName:=$(./latest-version.sh)}
cat CHANGELOG.md |sed -n "/^## $versionName\$/,/^##/{//!p;}" |sed '/./,$!d' |sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' 
