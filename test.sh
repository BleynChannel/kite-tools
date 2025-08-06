#!/bin/bash

HOME_PATH=$(getent passwd "$SUDO_USER" | cut -d: -f6)
echo $HOME_PATH
