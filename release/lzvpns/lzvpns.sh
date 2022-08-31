#!/bin/sh
# lzvpns.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# Main execution script

# BEIGIN

# ----------- User defined data area ------------

# The router port used by the VPN client to access the router from the WAN 
# using the domain name or IP address。
# 0--Primary WAN (Default), 1--Secondary WAN
WAN_ACCESS_PORT=0

# The router port used by the VPN client to access the WAN through the router.
# 0--Primary WAN (Default), 1--Secondary WAN
VPN_WAN_PORT=0

# Polling time to detect VPN client access.
# 1~10s (The default is 5 seconds)
POLLING_TIME=5

# ------------ global variable area -------------

# Project file deployment path。
PATH_BASE=/jffs/scripts
PATH_LZ="${0%/*}"
[ "${PATH_LZ:0:1}" != '/' ] && PATH_LZ="$( pwd )${PATH_LZ#*.}"
PATH_INTERFACE=${PATH_LZ}/interface
PATH_TMP=${PATH_LZ}/tmp

# Router WAN port router table ID.
WAN0=100
WAN1=200


# ---------------- Function area ----------------

# Initialize user-defined data。
Initialuserdata() {
    [ "${WAN_ACCESS_PORT}" -lt 0 -o "${WAN_ACCESS_PORT}" -gt 1 ] && WAN_ACCESS_PORT=0
    [ "${VPN_WAN_PORT}" -lt 0 -o "${VPN_WAN_PORT}" -gt 1 ] && VPN_WAN_PORT=0
    [ "${POLLING_TIME}" -lt 0 -o "${POLLING_TIME}" -gt 1 ] && POLLING_TIME=5
}

# --------- Script code execution area ----------

# END
