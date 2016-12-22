#!/bin/sh
set -xe

export F=production
make -r all
make -r test
make -r pkg
