#!/bin/sh
# lzvpnsd.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# VPN daemon script

# BEIGIN

PATH_INTERFACE="${0%/*}"
[ "${PATH_INTERFACE:0:1}" != '/' ] && PATH_INTERFACE="$( pwd )${PATH_INTERFACE#*.}"
PATH_TMP="${PATH_INTERFACE%/*}/tmp"
PATH_INTERFACE="${PATH_INTERFACE%/*}/interface"
VPN_DAEMON_DATA_FILE="lzvpnsd.dat"

# ------------- Data Exchange Area --------------
TRANSDATA=">>>>>>>>>"
# -----------------------------------------------

get_trsta() { echo "${TRANSDATA}" | awk -F '>' '{print $"'"${1}"'"}'; }

get_transdata() {
    [ "${TRANSDATA}" ] || return 1
	echo "${TRANSDATA}" | grep -qE '^[>]|[>][>]' && return 1
	POLLING_TIME="$( get_trsta "1" )"
	WAN0="$( get_trsta "2" )"
	WAN1="$( get_trsta "3" )"
	VPN_EVENT_INTERFACE_SCRIPTS="$( get_trsta "4" )"
	PPTP_CLIENT_IP_SET="$( get_trsta "5" )"
	IPSEC_SUBNET_IP_SET="$( get_trsta "6" )"
	VPN_DAEMON_IP_SET_LOCK="$( get_trsta "7" )"
	return 0
}

get_exta() { echo "${1}" | awk -F '>' 'NR=="'"${2}"'" {print $1}'; }

get_exdata() {
	[ ! -f "${PATH_TMP}/${VPN_DAEMON_DATA_FILE}" ] && return 1
	local data_buf="$( cat "${PATH_TMP}/${VPN_DAEMON_DATA_FILE}" 2> /dev/null )"
	[ "${data_buf}" ] || return 1
	POLLING_TIME="$( get_exta "${data_buf}" "1" )"
	WAN0="$( get_exta "${data_buf}" "2" )"
	WAN1="$( get_exta "${data_buf}" "3" )"
	VPN_EVENT_INTERFACE_SCRIPTS="$( get_exta "${data_buf}" "4" )"
	PPTP_CLIENT_IP_SET="$( get_exta "${data_buf}" "5" )"
	IPSEC_SUBNET_IP_SET="$( get_exta "${data_buf}" "6" )"
	VPN_DAEMON_IP_SET_LOCK="$( get_exta "${data_buf}" "7" )"
	return 0
}

get_data() {
	get_exdata && return 0
	get_transdata && return 0
	return 1
}

get_data || {
	POLLING_TIME=5
	WAN0=100
	WAN1=200
	VPN_EVENT_INTERFACE_SCRIPTS="lzvpnse.sh"
	PPTP_CLIENT_IP_SET="lzvpns_pptp_client"
	IPSEC_SUBNET_IP_SET="lzvpns_ipsec_subnet"
	VPN_DAEMON_IP_SET_LOCK="lzvpns_daemon_lock"
}

[ "${1}" -gt "0" ] && [ "${1}" -le "60" ] && POLLING_TIME="${1}"
POLLING_TIME="${POLLING_TIME}s"

ipset -! create "${VPN_DAEMON_IP_SET_LOCK}" list:set

PPTPD_ENABLE="$( nvram get pptpd_enable )"
IPSEC_SERVER_ENABLE="$( nvram get ipsec_server_enable )"

while [ -n "$( ipset -q -n list "${VPN_DAEMON_IP_SET_LOCK}" )" ]
do
	[ ! -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && break

	if [ "${PPTPD_ENABLE}" = "1" ]; then
		PPTPD_ENABLE="$( nvram get pptpd_enable )"
		if [ "${PPTPD_ENABLE}" != "1"  ]; then
			[ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && \
				sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
		else
			VPN_CLIENT=""
			VPN_CLIENT_LIST=$( ip route list | grep pptp | awk '{print $1}' )
			if [ -n "${VPN_CLIENT_LIST}" ]; then
				VPN_CLIENT_SUB_LIST=$( ip route list table "${WAN0}" | grep pptp | awk '{print $1}' )
				if [ -n "${VPN_CLIENT_SUB_LIST}" ]; then
					for VPN_CLIENT in ${VPN_CLIENT_LIST}
					do
						VPN_CLIENT=$( echo "${VPN_CLIENT_SUB_LIST}" | grep "${VPN_CLIENT}" )
						[ -z "${VPN_CLIENT}" ] && break
					done
					if [ -n "${VPN_CLIENT}" ]; then
						VPN_CLIENT_SUB_LIST=$( ip route list table "${WAN1}" | grep pptp | awk '{print $1}' )
						if [ -n "${VPN_CLIENT_SUB_LIST}" ]; then
							for VPN_CLIENT in ${VPN_CLIENT_LIST}
							do
								VPN_CLIENT=$( echo "${VPN_CLIENT_SUB_LIST}" | grep "${VPN_CLIENT}" )
								[ -z "${VPN_CLIENT}" ] && break
							done
						else
							VPN_CLIENT=""
						fi
					fi
				fi
				if [ -z "${VPN_CLIENT}" ]; then
					[ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && \
						sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
				else
					for VPN_CLIENT in $( ipset -q list "${PPTP_CLIENT_IP_SET}" | grep -Eo '([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}' )
					do
						if [ -z "$( echo "${VPN_CLIENT_LIST}" | grep "${VPN_CLIENT}" )" ]; then
							[ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && \
								sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
							break
						fi
					done
				fi
			else
				if [ -n "$( ipset -q list "${PPTP_CLIENT_IP_SET}" | grep -Eo '([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}' )" ]; then
					[ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && \
						sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
				fi
			fi
		fi
	fi

	if [ "${IPSEC_SERVER_ENABLE}" = "1" ]; then
		IPSEC_SERVER_ENABLE="$( nvram get ipsec_server_enable )"
		if [ "${IPSEC_SERVER_ENABLE}" != "1" ]; then
			[ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && \
				sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
		fi
	elif [ -n "$( ipset -q list $IPSEC_SUBNET_IP_SET | grep -Eo '([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}' )" ]; then
		[ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && \
			sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
	fi

	[ "${PPTPD_ENABLE}" != "1" ] && [ "${IPSEC_SERVER_ENABLE}" != "1" ] && break

	eval sleep "${POLLING_TIME}"
done

ipset -q destroy "${VPN_DAEMON_IP_SET_LOCK}"

# END
