#!/bin/sh
set -e

# Make sure debconf is in noninteractive mode
export DEBIAN_FRONTEND=noninteractive

# Install basic packages for the setup
apt-get update && apt-get -y install wget

# Install D-APT packages
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys EBCF975E5BA24D5E && \
        wget http://master.dl.sourceforge.net/project/d-apt/files/d-apt.list \
            -O /etc/apt/sources.list.d/d-apt.list

# Make sure our packages list is updated
apt-get update

# Install needed packages
apt-get -y install \
	lsb-release \
        build-essential \
        ruby-dev \
        git \
        rubygems-integration \
	dmd-bin \
	dub

# Build fpm
gem install fpm

# Create a docker user in case users want to run stuff without root
adduser --uid 65456 --gecos 'Docker User,,,' --disabled-password docker

