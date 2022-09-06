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
ROUTE_VPN_LIST=
IPSEC_SUBNET_LIST=
BALANCE_CHAIN=0
OVPN_SERVER_ENABLE=0
PPTPD_ENABLE=0
IPSEC_SERVER_ENABLE=0

MATCH_SET='--match-set'

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

delte_vpn_rules() {
    ip rule list | grep -wo "^${IP_RULE_PRIO_VPN}:" | awk -F: '{print "ip rule del prio "$1} END{print "ip route flush cache"}' \
        | awk '{system($0" > /dev/null 2>&1")}'
    return 0
}

detect_dual_wan() {
    ip route list | grep -q nexthop && return 0
    echo "$(lzdate)" [$$]: The dual WAN network is not connected. | tee -ai "${SYSLOG}" 2> /dev/null
    return 1
}

get_route_list() {
    ROUTE_LIST="$( ip route list | grep -Ev 'default|nexthop' )"
    [ -n "${ROUTE_LIST}" ] && return 0
    echo "$(lzdate)" [$$]: The router is faulty and the master routing table doesn\'t exist. | tee -ai "${SYSLOG}" 2> /dev/null
    return 1
}

get_ipsec_subnet_list() {
    IPSEC_SUBNET_LIST="$( nvram get ipsec_profile_1 | sed 's/>/\n/g' | sed -n 15p | grep -Eo '([0-9]{1,3}[\.]){2}[0-9]{1,3}' | sed 's/^.*$/&\.0\/24/' )"
    [ -z "${IPSEC_SUBNET_LIST}" ] && IPSEC_SUBNET_LIST="$( nvram get ipsec_profile_2 | sed 's/>/\n/g' | sed -n 15p | grep -Eo '([0-9]{1,3}[\.]){2}[0-9]{1,3}' | sed 's/^.*$/&\.0\/24/' )"
}

get_vpn_server() {
    echo "${ROUTE_LIST}" | grep -qE 'tun|tap' && OVPN_SERVER_ENABLE=1 || OVPN_SERVER_ENABLE=0
    PPTPD_ENABLE="$( nvram get pptpd_enable )"
    IPSEC_SERVER_ENABLE="$( nvram get ipsec_server_enable )"
    [ "${IPSEC_SERVER_ENABLE}" = "1" ] && get_ipsec_subnet_list
}

set_sub_route() {
    echo "${ROUTE_LIST}" | sed "s/^.*$/ip route add & table ${WAN0}/g" | awk '{system($0" > /dev/null 2>&1")}'
    echo "${ROUTE_LIST}" | sed "s/^.*$/ip route add & table ${WAN1}/g" | awk '{system($0" > /dev/null 2>&1")}'
    ROUTE_VPN_LIST="$( echo "${ROUTE_LIST}" | grep -E 'pptp|tun|tap' | awk '{print $1}' )"
}

set_vpn_rule() {
    local vpn_wan=
    [ "${VPN_WAN_PORT}" = "0" ] && vpn_wan="${WAN0}"
    [ "${VPN_WAN_PORT}" = "1" ] && vpn_wan="${WAN1}"
    [ -z "${vpn_wan}" ] && return
    echo "${ROUTE_VPN_LIST}" | sed "s/^.*$/ip rule add from & table ${vpn_wan} prio ${IP_RULE_PRIO_VPN}/g" | awk '{system($0" > /dev/null 2>&1")}'
    echo "${IPSEC_SUBNET_LIST}" | sed "s/^.*$/ip rule add from & table ${vpn_wan} prio ${IP_RULE_PRIO_VPN}/g" | awk '{system($0" > /dev/null 2>&1")}'
}

get_balance_chain() {
    iptables -t mangle -L PREROUTING 2> /dev/null | grep -qw balance && BALANCE_CHAIN=1 || BALANCE_CHAIN=0
}

clear_ipsets() {
    ipset -q destroy "${OVPN_SUBNET_IP_SET}"
    ipset -q destroy "${PPTP_CLIENT_IP_SET}"
    ipset -q destroy "${IPSEC_SUBNET_IP_SET}"
    return 0
}

create_vpn_ipsets_item() {
    if [ "${1}" = "1" ]; then
        ipset -! create "${2}" nethash; ipset -q flush "${2}";
    elif [ -n "$( ipset -q -n list "${2}" )" ]; then
        ipset -q destroy "${2}"
    fi
}

create_vpn_ipsets() {
    [ "${BALANCE_CHAIN}" != "1" ] && clear_ipsets && return
    create_vpn_ipsets_item "${OVPN_SERVER_ENABLE}" "${OVPN_SUBNET_IP_SET}"
    create_vpn_ipsets_item "${PPTPD_ENABLE}" "${PPTP_CLIENT_IP_SET}"
    create_vpn_ipsets_item "${IPSEC_SERVER_ENABLE}" "${IPSEC_SUBNET_IP_SET}"
    return
}

get_match_set() {
    case $( uname -m ) in
        armv7l)
            MATCH_SET='--match-set'
        ;;
        mips)
            MATCH_SET='--set'
        ;;
        aarch64)
            MATCH_SET='--match-set'
        ;;
        *)
            MATCH_SET='--match-set'
        ;;
    esac
    echo "${MATCH_SET}"
}

get_balance_used() {
    iptables -t mangle -L balance 2> /dev/null | grep -qw "${1}" && return 0
    return 1
}

delete_balance_items() {
    local number="$( iptables -t mangle -L balance -v -n --line-numbers 2> /dev/null \
            | grep -w "${1}" \
            | cut -d " " -f 1 | grep '^[0-9]*' | sort -nr )"
    [ -z "${number}" ] && return
    local item_no=
    for item_no in ${number}
    do
        iptables -t mangle -D balance "${item_no}" > /dev/null 2>&1
    done
}

set_balance_items() {
    if [ "${1}" = "1" ]; then
        if ! get_balance_used "${2}"; then
            iptables -t mangle -I balance -m set "${MATCH_SET}" "${2}" dst -j RETURN > /dev/null 2>&1
            if [ "${VPN_WAN_PORT}" = "0" ] || [ "${VPN_WAN_PORT}" = "1" ]; then
                iptables -t mangle -I balance -m set "${MATCH_SET}" "${2}" src -j RETURN > /dev/null 2>&1
            fi
        fi
    elif ! get_balance_used "${2}"; then
        delete_balance_items "${2}"
    fi
}

set_balance_chain() {
    [ "${BALANCE_CHAIN}" != "1" ] && return
    get_match_set
    set_balance_items "${OVPN_SERVER_ENABLE}" "${OVPN_SUBNET_IP_SET}"
    set_balance_items "${PPTPD_ENABLE}" "${PPTP_CLIENT_IP_SET}"
    set_balance_items "${IPSEC_SERVER_ENABLE}" "${IPSEC_SUBNET_IP_SET}"
}

set_balance_rule() {
    [ "${BALANCE_CHAIN}" != "1" ] && return
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
    delte_vpn_rules
    detect_dual_wan || break
    get_route_list || break
    get_vpn_server
    set_sub_route
    set_vpn_rule
    get_balance_chain
    create_vpn_ipsets
    set_balance_chain
    set_balance_rule
done


unset_lock

exit 0

# END
