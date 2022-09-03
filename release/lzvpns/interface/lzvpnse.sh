#!/bin/sh
# lzvpnse.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# VPN event processing script

# BEIGIN

VPN_WAN_PORT=0
WAN0=100
WAN1=200
IP_RULE_PRIO_VPN=998
OVPN_SUBNET_IP_SET="lzvpns_ovpn_subnet"
PPTP_CLIENT_IP_SET="lzvpns_pptp_client"
IPSEC_SUBNET_IP_SET="lzvpns_ipsec_subnet"
SYSLOG="/tmp/syslog.log"

# ------------- Data Exchange Area --------------
# ---------- Don't manually modify !!! ----------
TRANSDATA=">>>>>>>>"
# ---------- Don't manually modify !!! ----------
# -----------------------------------------------

get_trsta() { echo "$( echo "${TRANSDATA}" | awk -F '>' '{print $"'"${1}"'"}' )"; }

get_transdata() {
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

lzdate() { echo "$( date +"%F %T" )"; }


get_transdata

# END
