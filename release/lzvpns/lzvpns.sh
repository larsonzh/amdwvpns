#!/bin/sh
# lzvpns.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# LZ script for asuswrt/merlin based router

# Script command: (e.g., in the lzvpns Directory)
# Start/Restart:  ./lzvpns.sh
# Stop:           ./lzvpns.sh stop


# Main execution script

# BEIGIN

#  ------------- User defined data --------------

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


# --------------- global variable ---------------

# Project ID
PROJECT_ID=lzvpns

# main execution script file
MAIN_SCRIPTS=${PROJECT_ID}.sh

# VPN event processing script file
VPN_EVENT_INTERFACE_SCRIPTS=lzvpnse.sh

# VPN daemon script file
VPN_DAEMON_SCRIPTS=lzvpnsd.sh

# Self boot and event trigger files
BOOTLOADER_FILE=firewall-start
VPN_EVENT_FILE=openvpn-event

# Project file deployment path.
PATH_BOOTLOADER=/jffs/scripts
PATH_LZ="${0%/*}"
[ "${PATH_LZ:0:1}" != '/' ] && PATH_LZ="$( pwd )${PATH_LZ#*.}"
PATH_INTERFACE=${PATH_LZ}/interface
PATH_TMP=${PATH_LZ}/tmp

# Router WAN port router table ID.
WAN0=100
WAN1=200

# System event log file
SYSLOG_FILE="/tmp/syslog.log"


# ------------------ Function -------------------

cleaning_user_data() {
    [ "${WAN_ACCESS_PORT}" -lt 0 -o "${WAN_ACCESS_PORT}" -gt 1 ] && WAN_ACCESS_PORT=0
    [ "${VPN_WAN_PORT}" -lt 0 -o "${VPN_WAN_PORT}" -gt 1 ] && VPN_WAN_PORT=0
    [ "${POLLING_TIME}" -lt 0 -o "${POLLING_TIME}" -gt 10 ] && POLLING_TIME=5
}

init_directory() {
	[ ! -d ${PATH_LZ} ] && mkdir -p ${PATH_LZ} > /dev/null 2>&1
	chmod 775 ${PATH_LZ} > /dev/null 2>&1
	[ ! -d ${PATH_INTERFACE} ] && mkdir -p ${PATH_INTERFACE} > /dev/null 2>&1
	chmod 775 ${PATH_INTERFACE} > /dev/null 2>&1
	[ ! -d ${PATH_TMP} ] && mkdir -p ${PATH_TMP} > /dev/null 2>&1
	chmod 775 ${PATH_TMP} > /dev/null 2>&1
	cd ${PATH_INTERFACE}/ > /dev/null 2>&1 && chmod -R 775 * > /dev/null 2>&1
	cd ${PATH_TMP}/ > /dev/null 2>&1 && chmod -R 775 * > /dev/null 2>&1
	cd ${PATH_LZ}/ > /dev/null 2>&1 && chmod -R 775 * > /dev/null 2>&1
}

check_file() {
	local scripts_file_exist=0
	[ ! -f ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} ] && {
		echo $(date) [$$]: ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} does not exist. | tee -ai ${SYSLOG_FILE} 2> /dev/null
		scripts_file_exist=1
	}
	[ ! -f ${PATH_INTERFACE}/${VPN_DAEMON_SCRIPTS} ] && {
		echo $(date) [$$]: ${PATH_INTERFACE}/${VPN_DAEMON_SCRIPTS} does not exist. | tee -ai ${SYSLOG_FILE} 2> /dev/null
		scripts_file_exist=1
	}
	if [ "$scripts_file_exist" = 1 ]; then
		echo -e $(date) [$$]: Dual WAN VPN support service can\'t be started. | tee -ai ${SYSLOG_FILE} 2> /dev/null
		echo $(date) [$$]: | tee -ai ${SYSLOG_FILE} 2> /dev/null
		exit 1
	fi
}


# ------------ Script code execution ------------

cleaning_user_data
init_directory
check_file

# END
