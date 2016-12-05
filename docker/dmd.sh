#!/bin/sh
# Depends: base.sh
# Params:
#   - dmd-bin package version (default: latest)
set -xe

dmd_version="2.071.2"

apt -y install xdg-utils libcurl3

wget -O dmd.deb http://downloads.dlang.org/releases/2.x/${dmd_version}/dmd_${dmd_version}-0_amd64.deb
dpkg -i dmd.deb
