#!/bin/sh
set -xe

id
git submodule foreach --recursive git submodule deinit --force --all
make F=production all test deb
