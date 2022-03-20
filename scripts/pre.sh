#! /usr/bin/env bash

# Disable fancy progressbar
echo 'Dpkg::Progress-Fancy "0";' > /etc/apt/apt.conf.d/99progressbar
echo 'Dpkg::Use-Pty "0";' >> /etc/apt/apt.conf.d/99progressbar
