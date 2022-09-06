#!/bin/sh
# lzvpnse.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# VPN event processing script

# BEIGIN

PATH_TMP="${0%/*}"
[ "${PATH_TMP:0:1}" != '/' ] && PATH_TMP="$( pwd )${PATH_TMP#*.}"
PATH_TMP="${PATH_TMP%/*}/tmp"
VPN_DATA_FILE="lzvpnsd.dat"

PATH_LOCK="/var/lock"
LOCK_FILE="${PATH_LOCK}/lzvpns.lock"
LOCK_FILE_ID=555

# ------------- Data Exchange Area --------------
TRANSDATA=">>>>>>>>"
# -----------------------------------------------

get_trsta() { echo "${TRANSDATA}" | awk -F '>' '{print $"'"${1}"'"}'; }

get_transdata() {
	[ "${TRANSDATA}" ] || return 1
    [ -n "$( echo "${TRANSDATA}" | grep -E '^[>]|[>][>]' )" ] && return 1
    VPN_WAN_PORT="$( get_trsta "1" )"
    WAN0="$( get_trsta "2" )"
    WAN1="$( get_trsta "3" )"
    IP_RULE_PRIO_VPN="$( get_trsta "4" )"
    OVPN_SUBNET_IP_SET="$( get_trsta "5" )"
    PPTP_CLIENT_IP_SET="$( get_trsta "6" )"
    IPSEC_SUBNET_IP_SET="$( get_trsta "7" )"
    SYSLOG="$( get_trsta "8" )"
}

get_exta() { echo "${1}" | awk -F '>' 'NR=="'"${2}"'" {print $1}'; }

get_exdata() {
	[ ! -f "${PATH_TMP}/${VPN_DATA_FILE}" ] && return 1
	local data_buf="$( cat "${PATH_TMP}/${VPN_DATA_FILE}" 2> /dev/null )"
	[ "${data_buf}" ] || return 1
	VPN_WAN_PORT="$( get_exta "${data_buf}" "1" )"
	WAN0="$( get_exta "${data_buf}" "2" )"
	WAN1="$( get_exta "${data_buf}" "3" )"
	IP_RULE_PRIO_VPN="$( get_exta "${data_buf}" "4" )"
	OVPN_SUBNET_IP_SET="$( get_exta "${data_buf}" "5" )"
	PPTP_CLIENT_IP_SET="$( get_exta "${data_buf}" "6" )"
	IPSEC_SUBNET_IP_SET="$( get_exta "${data_buf}" "7" )"
	SYSLOG="$( get_exta "${data_buf}" "8" )"
	return 0
}

get_data() {
	get_exdata && return 0
	get_transdata && return 0
	return 1
}

set_lock() {
    [ ! -d "${PATH_LOCK}" ] && { mkdir -p "${PATH_LOCK}" > /dev/null 2>&1; chmod 777 "${PATH_LOCK}" > /dev/null 2>&1; }
    exec 555<>"${LOCK_FILE}"; flock -x "${LOCK_FILE_ID}" > /dev/null 2>&1;
}

unset_lock() {
    flock -u "${LOCK_FILE_ID}" > /dev/null 2>&1
}

lzdate() { echo "$( date +"%F %T" )"; }

set_lock

get_data || {
    VPN_WAN_PORT=0
    WAN0=100
    WAN1=200
    IP_RULE_PRIO_VPN=998
    OVPN_SUBNET_IP_SET="lzvpns_ovpn_subnet"
    PPTP_CLIENT_IP_SET="lzvpns_pptp_client"
    IPSEC_SUBNET_IP_SET="lzvpns_ipsec_subnet"
    SYSLOG="/tmp/syslog.log"
}

unset_lock

exit 0

# END
