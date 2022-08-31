#!/bin/sh
# lzvpns.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# Main execution script

# BEIGIN

# ------ User parameter configuration area ------

# The router port used by the VPN client to access the router from the WAN using the domain name or IP address。
# 0--Primary WAN (Default), 1--Secondary WAN
WAN_ACCESS_PORT=0

# The router port used by the VPN client to access the WAN through the router.
# 0--Primary WAN (Default), 1--Secondary WAN
VPN_WAN_PORT=0

# Polling time to detect VPN client access.
# 1~10s (The default is 5 seconds)
POLLING_TIME=5

# ------------ global variable area -------------

# Router WAN port router table ID.
WAN0=100
WAN1=200

# ---------------- Function area ----------------

# --------- Script code execution area ----------

# END
