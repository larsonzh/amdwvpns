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

# System event log file
SYSLOG_FILE="/tmp/syslog.log"

# Project ID
PROJECT_ID="lzvpns"

# main execution script file
MAIN_SCRIPTS="${PROJECT_ID}.sh"

# VPN event processing script file
VPN_EVENT_INTERFACE_SCRIPTS="lzvpnse.sh"

# VPN daemon script file
VPN_DAEMON_SCRIPTS="lzvpnsd.sh"

# Self boot and event trigger files
BOOTLOADER_FILE="firewall-start"
VPN_EVENT_FILE="openvpn-event"

# Project file deployment path.
PATH_BOOTLOADER="/jffs/scripts"
PATH_LZ="${0%/*}"
[ "${PATH_LZ:0:1}" != '/' ] && PATH_LZ="$( pwd )${PATH_LZ#*.}"
PATH_INTERFACE="${PATH_LZ}/interface"
PATH_DAEMON="${PATH_LZ}/daemon"
PATH_TMP="${PATH_LZ}/tmp"

# Router WAN port VPN routing table ID.
VPN_WAN0=998
VPN_WAN1=999

## Router host access WAN policy routing rule priority
IP_RULE_PRIO_HOST=999

# VPN client access WAN policy routing rule priority
IP_RULE_PRIO_VPN=998

## OpenVPN subnet address list data set
OVPN_SUBNET_IP_SET="lzvpns_openvpn_subnet"

# PPTP VPN client local address list dataset
PPTP_CLIENT_IP_SET="lzvpns_pptp_client"

# IPSec VPN subnet address list data set
IPSEC_SUBNET_IP_SET="lzvpns_ipsec_subnet"

# VPN daemon startup script
VPN_DAEMON_START_SCRIPT="lzvpns_start_daemon.sh"

# Start VPN daemon time task ID
START_DAEMON_TIMEER_ID="lzvpns_start_daemon_id"


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
	[ ! -f ${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS} ] && {
		echo $(date) [$$]: ${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS} does not exist. | tee -ai ${SYSLOG_FILE} 2> /dev/null
		scripts_file_exist=1
	}
	if [ "$scripts_file_exist" = 1 ]; then
		echo -e $(date) [$$]: Dual WAN VPN support service can\'t be started. | tee -ai ${SYSLOG_FILE} 2> /dev/null
		echo $(date) [$$]: | tee -ai ${SYSLOG_FILE} 2> /dev/null
		exit 1
	fi
}

clear_ip_rules() {
    ip rule list | grep -wo "^${1}" | awk '{print "ip rule del prio "$1} END{print "ip route flush cache"}' | awk '{system($0" > /dev/null 2>&1")}'
}

clear_routing_table() {
	local item=
	for item in $( ip route list table ${1} )
	do
		ip route del ${item} table ${1} > /dev/null 2>&1
	done
	ip route flush cache > /dev/null 2>&1
}

transfer_parameters() {
	sed -i "s:WAN_ACCESS_PORT=.*$:WAN_ACCESS_PORT="${WAN_ACCESS_PORT}":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
	sed -i "s:VPN_WAN_PORT=.*$:VPN_WAN_PORT="${VPN_WAN_PORT}":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
	sed -i "s:POLLING_TIME=.*$:POLLING_TIME="${POLLING_TIME}":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
	sed -i "s:VPN_WAN0=.*$:VPN_WAN0="${VPN_WAN0}":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
	sed -i "s:VPN_WAN1=.*$:VPN_WAN1="${VPN_WAN1}":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
	sed -i "s:IP_RULE_PRIO_HOST=.*$:IP_RULE_PRIO_HOST="${IP_RULE_PRIO_HOST}":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
	sed -i "s:IP_RULE_PRIO_VPN=.*$:IP_RULE_PRIO_VPN="${IP_RULE_PRIO_VPN}":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
	sed -i "s:OVPN_SUBNET_IP_SET=.*$:OVPN_SUBNET_IP_SET=\""${OVPN_SUBNET_IP_SET}"\":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
	sed -i "s:PPTP_CLIENT_IP_SET=.*$:PPTP_CLIENT_IP_SET=\""${PPTP_CLIENT_IP_SET}"\":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
	sed -i "s:IPSEC_SUBNET_IP_SET=.*$:IPSEC_SUBNET_IP_SET=\""${IPSEC_SUBNET_IP_SET}"\":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
	sed -i "s:SYSLOG_FILE=.*$:SYSLOG_FILE=\""${SYSLOG_FILE}"\":g" ${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS} > /dev/null 2>&1
}


# -------------- Script execution ---------------

cleaning_user_data
clear_ip_rules "${IP_RULE_PRIO_VPN}"
clear_ip_rules "${IP_RULE_PRIO_HOST}"
clear_routing_table "${VPN_WAN0}"
clear_routing_table "${VPN_WAN1}"
init_directory
check_file
transfer_parameters

# END
