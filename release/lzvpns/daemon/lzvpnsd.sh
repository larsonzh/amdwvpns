#!/bin/sh
# lzvpnsd.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# VPN daemon script

# BEIGIN

PATH_INTERFACE="${0%/*}"
[ "${PATH_INTERFACE:0:1}" != '/' ] && PATH_INTERFACE="$( pwd )${PATH_INTERFACE#*.}"
PATH_INTERFACE=“${PATH_INTERFACE%/*}/interface”

WAN0=100; WAN1=200;
VPN_EVENT_INTERFACE_SCRIPTS="lzvpnse.sh"
PPTP_CLIENT_IP_SET="lzvpns_pptp_client"
IPSEC_SUBNET_IP_SET="lzvpns_ipsec_subnet"
VPN_DAEMON_IP_SET_LOCK="lzvpns_daemon_lock"
ipset -! create "${VPN_DAEMON_IP_SET_LOCK}" nethash

POLLING_TIME=5
[ "${1}" -gt 0 -a "${1}" -le 60 ] && POLLING_TIME="${1}"
POLLING_TIME=$( echo "${POLLING_TIME}" | sed 's/\(^.*$\)/\1s/g' )

PPTPD_ENABLE="$( nvram get pptpd_enable)"
IPSEC_SERVER_ENABLE="$( nvram get ipsec_server_enable)"

while [ -n "$( ipset -q -n list "${VPN_DAEMON_IP_SET_LOCK}" )" ]
do
	if [ "${PPTPD_ENABLE}" = "1" ]; then
		PPTPD_ENABLE="$( nvram get pptpd_enable)"
		if [ "${PPTPD_ENABLE}" != "1" ]; then
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
					sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
				else
					for VPN_CLIENT in $( ipset -q list "${PPTP_CLIENT_IP_SET}" | grep -Eo '([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}' )
					do
						[ -z "$( echo "${VPN_CLIENT_LIST}" | grep "${VPN_CLIENT}" )" ] \
							&& sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" \
							&& break
					done
				fi
			else
				[ -n "$( ipset -q list "${PPTP_CLIENT_IP_SET}" | grep -Eo '([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}' )" ] \
					&& sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
			fi
		fi
	fi

	if [ "${IPSEC_SERVER_ENABLE}" = "1" ]; then
		IPSEC_SERVER_ENABLE="$( nvram get ipsec_server_enable)"
		[ "${IPSEC_SERVER_ENABLE}" != "1" ] && sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
	elif [ -n "$( ipset -q list $IPSEC_SUBNET_IP_SET | grep -Eo '([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}' )" ]; then
		sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
	fi

	[ "${PPTPD_ENABLE}" != "1" -a "${IPSEC_SERVER_ENABLE}" != "1" ] && break

	eval sleep "${POLLING_TIME}"
done

ipset -q destroy "${VPN_DAEMON_IP_SET_LOCK}"

# END
