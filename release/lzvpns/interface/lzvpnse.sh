#!/bin/sh
# lzvpnse.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# VPN event processing script

# BEIGIN

PATH_TMP="${0%/*}"
[ "${PATH_TMP:0:1}" != '/' ] && PATH_TMP="$( pwd )${PATH_TMP#*.}"
PATH_TMP="${PATH_TMP%/*}/tmp"
VPN_DATA_FILE="lzvpnse.dat"

PATH_LOCK="/var/lock"
LOCK_FILE="${PATH_LOCK}/lz_rule.lock"
LOCK_FILE_ID=555

ROUTE_LIST=
OVPN_SERVER_ENABLE=0
PPTPD_ENABLE=0
IPSEC_SERVER_ENABLE=0

# ------------- Data Exchange Area --------------
TRANSDATA=">>>>>>>>>"
# -----------------------------------------------

get_trsta() { echo "${TRANSDATA}" | awk -F '>' '{print $"'"${1}"'"}'; }

get_transdata() {
    [ "${TRANSDATA}" ] || return 1
    echo "${TRANSDATA}" | grep -qE '^[>]|[>][>]' && return 1
    LZ_VERSION="$( get_trsta "1" )"
    VPN_WAN_PORT="$( get_trsta "2" )"
    WAN0="$( get_trsta "3" )"
    WAN1="$( get_trsta "4" )"
    IP_RULE_PRIO_VPN="$( get_trsta "5" )"
    OVPN_SUBNET_IP_SET="$( get_trsta "6" )"
    PPTP_CLIENT_IP_SET="$( get_trsta "7" )"
    IPSEC_SUBNET_IP_SET="$( get_trsta "8" )"
    SYSLOG="$( get_trsta "9" )"
}

get_exta() { echo "${1}" | awk -F '>' 'NR=="'"${2}"'" {print $1}'; }

get_exdata() {
    [ ! -f "${PATH_TMP}/${VPN_DATA_FILE}" ] && return 1
    local data_buf="$( cat "${PATH_TMP}/${VPN_DATA_FILE}" 2> /dev/null )"
    [ "${data_buf}" ] || return 1
    LZ_VERSION="$( get_exta "${data_buf}" "1" )"
    VPN_WAN_PORT="$( get_exta "${data_buf}" "2" )"
    WAN0="$( get_exta "${data_buf}" "3" )"
    WAN1="$( get_exta "${data_buf}" "4" )"
    IP_RULE_PRIO_VPN="$( get_exta "${data_buf}" "5" )"
    OVPN_SUBNET_IP_SET="$( get_exta "${data_buf}" "6" )"
    PPTP_CLIENT_IP_SET="$( get_exta "${data_buf}" "7" )"
    IPSEC_SUBNET_IP_SET="$( get_exta "${data_buf}" "8" )"
    SYSLOG="$( get_exta "${data_buf}" "9" )"
    return 0
}

get_data() {
    get_exdata && return 0
    get_transdata && return 0
    return 1
}

set_lock() {
    [ ! -d "${PATH_LOCK}" ] && { mkdir -p "${PATH_LOCK}" > /dev/null 2>&1; chmod 777 "${PATH_LOCK}" > /dev/null 2>&1; }
    eval exec "${LOCK_FILE_ID}"<>"${LOCK_FILE}"
    flock -x "${LOCK_FILE_ID}" > /dev/null 2>&1;
}

unset_lock() {
    flock -u "${LOCK_FILE_ID}" > /dev/null 2>&1
}

delte_ip_rules() {
    ip rule list | grep -wo "^${1}" | awk '{print "ip rule del prio "$1} END{print "ip route flush cache"}' \
        | awk '{system($0" > /dev/null 2>&1")}'
    return 0
}

detect_dual_wan() {
    ip route list | grep -q nexthop && return 0
    echo "$(lzdate)" [$$]: The dual WAN network is not connected. | tee -ai "${SYSLOG}" 2> /dev/null
    return 1
}

detect_balance_chain() {
    iptables -t mangle -L PREROUTING 2> /dev/null | grep -qw balance && return 0
    return 1
}

clear_ipsets() {
    ipset -q destroy "${OVPN_SUBNET_IP_SET}"
    ipset -q destroy "${PPTP_CLIENT_IP_SET}"
    ipset -q destroy "${IPSEC_SUBNET_IP_SET}"
    return 0
}

get_router_list() {
    ROUTE_LIST="$( ip route list | grep -Ev 'default|nexthop' )"
    [ -n "${ROUTE_LIST}" ] return 0
    echo "$(lzdate)" [$$]: The router is faulty and the master routing table doesn\'t exist. | tee -ai "${SYSLOG}" 2> /dev/null
    return 1
}

get_vpn_server_status() {
    echo "${ROUTE_LIST}" | grep -qE 'tun|tap' && OVPN_SERVER_ENABLE=1 || OVPN_SERVER_ENABLE=0
    PPTPD_ENABLE="$( nvram get pptpd_enable )"
    IPSEC_SERVER_ENABLE="$( nvram get ipsec_server_enable )"
}

create_vpn_ipsets() {
    ! detect_balance_chain && clear_ipsets && return 1
    if [ "${OVPN_SERVER_ENABLE}" = "1" ]; then
        ipset -! create "${OVPN_SUBNET_IP_SET}" nethash; ipset -q flush "${OVPN_SUBNET_IP_SET}";
    elif [ -n "$( ipset -q -n list "${OVPN_SUBNET_IP_SET}" )" ]; then
        ipset -q destroy "${OVPN_SUBNET_IP_SET}"
    fi
     if [ "${PPTPD_ENABLE}" = "1" ]; then
        ipset -! create "${PPTP_CLIENT_IP_SET}" nethash; ipset -q flush "${PPTP_CLIENT_IP_SET}";
    elif [ -n "$( ipset -q -n list "${PPTP_CLIENT_IP_SET}" )" ]; then
        ipset -q destroy "${PPTP_CLIENT_IP_SET}"
    fi
    if [ "${IPSEC_SERVER_ENABLE}" = "1" ]; then
        ipset -! create "${IPSEC_SUBNET_IP_SET}" nethash; ipset -q flush "${IPSEC_SUBNET_IP_SET}";
    elif [ -n "$( ipset -q -n list "${IPSEC_SUBNET_IP_SET}" )" ]; then
        ipset -q destroy "${IPSEC_SUBNET_IP_SET}"
    fi
}


lzdate() { eval echo "$( date +"%F %T" )"; }


set_lock

get_data || {
    LZ_VERSION=v0.0.1
    VPN_WAN_PORT=0
    WAN0=100
    WAN1=200
    IP_RULE_PRIO_VPN=998
    OVPN_SUBNET_IP_SET="lzvpns_ovpn_subnet"
    PPTP_CLIENT_IP_SET="lzvpns_pptp_client"
    IPSEC_SUBNET_IP_SET="lzvpns_ipsec_subnet"
    SYSLOG="/tmp/syslog.log"
}

echo "$(lzdate)" [$$]: | tee -ai "${SYSLOG}" 2> /dev/null
echo "$(lzdate)" [$$]: Running LZ VPNS Event Handling Process "${LZ_VERSION}" | tee -ai "${SYSLOG}" 2> /dev/null

while true
do
    delte_ip_rules "${IP_RULE_PRIO_VPN}"
    detect_dual_wan || break
    get_router_list || break
    get_vpn_server_status
    create_vpn_ipsets
done


unset_lock

exit 0

# END
