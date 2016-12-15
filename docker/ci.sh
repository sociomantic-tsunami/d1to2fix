#!/bin/sh
set -xe

make F=production all test deb
