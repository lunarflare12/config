#!/bin/sh
hyprctl reload
systemctl --user restart quickshell.service
