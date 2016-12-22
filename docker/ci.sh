#!/bin/sh
set -xe

export F=production
make all
make test
make pkg
