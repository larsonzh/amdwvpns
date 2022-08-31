#!/bin/sh
# lzvpns.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# Main execution script

# BEIGIN

# ------ User parameter configuration area ------

# The client accesses the WAN port of the router from the outside through the domain name or IP address
# 0--Primary WAN (Default), 1--Secondary WAN
WAN_ACCESS_PORT=0

#The VPN client accesses the router exit of the WAN through the router
# 0--Primary WAN (Default), 1--Secondary WAN
VPN_CLIENT_WAN_PORT=0

# Polling time to detect VPN client access
# 1~10s (The default is 5 seconds)
POLLING_TIME=5

# ------------ global variable area -------------

# ---------------- Function area ----------------

# --------- Script code execution area ----------

# END
