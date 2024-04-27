#!/bin/sh
cur="$(dirname $0)"
cd $cur
cat CHANGELOG.md |sed '1,/^$/d' |head -1 |sed  's/^## \(.*\)/\1/'
