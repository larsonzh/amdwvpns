#!/bin/sh
# lzvpnse.sh v1.0.5
# By LZ (larsonzhang@gmail.com)

# LZ VPNS script for asuswrt/merlin based router

# VPN event processing script

# BEIGIN

# --------------- Global Variable ---------------

HAMMER="${1}"
PATH_TMP="${0%/*}"
[ "${PATH_TMP:0:1}" != '/' ] && PATH_TMP="$( pwd )${PATH_TMP#*.}"
PATH_TMP="${PATH_TMP%/*}/tmp"
VPN_DATA_FILE="lzvpnse.dat"

PATH_LOCK="/var/lock"
LOCK_FILE="${PATH_LOCK}/lz_rule.lock"
LOCK_FILE_ID=555

ROUTE_LIST=""
IPSEC_SUBNET_LIST=""
OVPN_SERVER_ENABLE="0"
PPTPD_ENABLE="0"
IPSEC_SERVER_ENABLE="0"
WGS_ENABLE="0"

MATCH_SET='--match-set'


# ------------- Data Exchange Area --------------
TRANSDATA=">>>>>>>>>>>>"
# -----------------------------------------------


# ------------------ Function -------------------

get_trsta() { echo "${TRANSDATA}" | awk -F '>' '{print $"'"${1}"'"}'; }

get_transdata() {
    [ "${TRANSDATA}" ] || return "1"
    echo "${TRANSDATA}" | grep -qE '^[>]|[>][>]' && return "1"
    LZ_VERSION="$( get_trsta "1" )"
    WAN_ACCESS_PORT="$( get_trsta "2" )"
    VPN_WAN_PORT="$( get_trsta "3" )"
    POLLING_TIME="$( get_trsta "4" )"
    WAN0="$( get_trsta "5" )"
    WAN1="$( get_trsta "6" )"
    IP_RULE_PRIO_VPN="$( get_trsta "7" )"
    OVPN_SUBNET_IP_SET="$( get_trsta "8" )"
    PPTP_CLIENT_IP_SET="$( get_trsta "9" )"
    IPSEC_SUBNET_IP_SET="$( get_trsta "10" )"
    WIREGUARD_CLIENT_IP_SET="$( get_trsta "11" )"
    SYSLOG="$( get_trsta "12" )"
}

get_exta() { echo "${1}" | awk -F '>' 'NR=="'"${2}"'" {print $1}'; }

get_exdata() {
    [ ! -f "${PATH_TMP}/${VPN_DATA_FILE}" ] && return "1"
    local data_buf="$( cat "${PATH_TMP}/${VPN_DATA_FILE}" 2> /dev/null )"
    [ "${data_buf}" ] || return "1"
    LZ_VERSION="$( get_exta "${data_buf}" "1" )"
    WAN_ACCESS_PORT="$( get_exta "${data_buf}" "2" )"
    VPN_WAN_PORT="$( get_exta "${data_buf}" "3" )"
    POLLING_TIME="$( get_exta "${data_buf}" "4" )"
    WAN0="$( get_exta "${data_buf}" "5" )"
    WAN1="$( get_exta "${data_buf}" "6" )"
    IP_RULE_PRIO_VPN="$( get_exta "${data_buf}" "7" )"
    OVPN_SUBNET_IP_SET="$( get_exta "${data_buf}" "8" )"
    PPTP_CLIENT_IP_SET="$( get_exta "${data_buf}" "9" )"
    IPSEC_SUBNET_IP_SET="$( get_exta "${data_buf}" "10" )"
    WIREGUARD_CLIENT_IP_SET="$( get_exta "${data_buf}" "11" )"
    SYSLOG="$( get_exta "${data_buf}" "12" )"
    return "0"
}

get_data() {
    get_exdata && return "0"
    get_transdata && return "0"
    return "1"
}


cleaning_user_data() {
    [ "${WAN_ACCESS_PORT}" != "0" ] && [ "${WAN_ACCESS_PORT}" != "1" ] && WAN_ACCESS_PORT="0"
    ! echo "${POLLING_TIME}" | grep -qE '^[0-9]$|^[1][0]$' && POLLING_TIME="3"
}

set_lock() {
    [ "${HAMMER}" = "${PATH_TMP%/*}/interface" ] && return
    [ ! -d "${PATH_LOCK}" ] && { mkdir -p "${PATH_LOCK}" > /dev/null 2>&1; chmod 777 "${PATH_LOCK}" > /dev/null 2>&1; }
    eval "exec ${LOCK_FILE_ID}<>${LOCK_FILE}"
    flock -x "${LOCK_FILE_ID}" > /dev/null 2>&1;
}

unset_lock() {
    [ "${HAMMER}" = "${PATH_TMP%/*}/interface" ] && return
    flock -u "${LOCK_FILE_ID}" > /dev/null 2>&1
}

lzdate() { date +"%F %T"; }

delte_vpn_rules() {
    ip rule list | awk -v count="0" -F: '$1 == "'"${IP_RULE_PRIO_VPN}"'" {system("ip rule del prio "$1" > /dev/null 2>&1"); count++} \
        END{if (count != "0") system("ip route flush cache > /dev/null 2>&1")}'
    return "0"
}

detect_dual_wan() {
    ip route list | grep -q nexthop && return "0"
    echo "$(lzdate)" [$$]: The dual WAN network is not connected. | tee -ai "${SYSLOG}" 2> /dev/null
    return "1"
}

get_route_list() {
    ROUTE_LIST="$( ip route list | grep -Ev 'default|nexthop' )"
    [ -n "${ROUTE_LIST}" ] && return "0"
    echo "$(lzdate)" [$$]: The router is faulty and the master routing table doesn\'t exist. | tee -ai "${SYSLOG}" 2> /dev/null
    return "1"
}

get_ipsec_subnet_list() {
    IPSEC_SUBNET_LIST="$( nvram get ipsec_profile_1 | sed 's/>/\n/g' \
        | sed -n 15p | grep -Eo '([0-9]{1,3}[\.]){2}[0-9]{1,3}' | sed 's/^.*$/&\.0\/24/' )"
    [ -z "${IPSEC_SUBNET_LIST}" ] && IPSEC_SUBNET_LIST="$( nvram get ipsec_profile_2 | sed 's/>/\n/g' \
        | sed -n 15p | grep -Eo '([0-9]{1,3}[\.]){2}[0-9]{1,3}' | sed 's/^.*$/&\.0\/24/' )"
}

get_vpn_server_status() {
    echo "${ROUTE_LIST}" | grep -qE 'tun|tap' && OVPN_SERVER_ENABLE="1" || OVPN_SERVER_ENABLE="0"
    PPTPD_ENABLE="$( nvram get pptpd_enable )"
    IPSEC_SERVER_ENABLE="$( nvram get ipsec_server_enable )"
    [ "${IPSEC_SERVER_ENABLE}" = "1" ] && get_ipsec_subnet_list || IPSEC_SUBNET_LIST=""
    WGS_ENABLE="$( nvram get wgs_enable )"
}

set_vpn_sub_route() {
    echo "${ROUTE_LIST}" | awk 'NF != "0" {system("ip route add "$0"'" table ${WAN0} > /dev/null 2>&1"'")}'
    echo "${ROUTE_LIST}" | awk 'NF != "0" {system("ip route add "$0"'" table ${WAN1} > /dev/null 2>&1"'")}'
}

set_vpn_rule() {
    local vpn_wan=
    [ "${VPN_WAN_PORT}" = "0" ] && vpn_wan="${WAN0}"
    [ "${VPN_WAN_PORT}" = "1" ] && vpn_wan="${WAN1}"
    [ -z "${vpn_wan}" ] && return
    echo "${ROUTE_LIST}"| awk '/pptp|tun|tap|wgs/ {system("ip rule add from "$1"'" table ${vpn_wan} prio ${IP_RULE_PRIO_VPN} > /dev/null 2>&1"'")}'
    echo "${IPSEC_SUBNET_LIST}"| awk '$1 ~ /([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}/ {system("ip rule add from "$1"'" table ${vpn_wan} prio ${IP_RULE_PRIO_VPN} > /dev/null 2>&1"'")}'
}

clear_vpn_ipsets() {
    ipset -q destroy "${OVPN_SUBNET_IP_SET}"
    ipset -q destroy "${PPTP_CLIENT_IP_SET}"
    ipset -q destroy "${IPSEC_SUBNET_IP_SET}"
    ipset -q destroy "${WIREGUARD_CLIENT_IP_SET}"
    return "0"
}

get_balance_chain() {
    iptables -t mangle -L PREROUTING 2> /dev/null | grep -qw balance && return "0" || return "1"
}

create_vpn_ipsets_item() {
    [ "${1}" != "1" ] && return
    ipset -! create "${2}" nethash; ipset -q flush "${2}";
}

create_vpn_ipsets() {
    create_vpn_ipsets_item "${OVPN_SERVER_ENABLE}" "${OVPN_SUBNET_IP_SET}"
    create_vpn_ipsets_item "${PPTPD_ENABLE}" "${PPTP_CLIENT_IP_SET}"
    create_vpn_ipsets_item "${IPSEC_SERVER_ENABLE}" "${IPSEC_SUBNET_IP_SET}"
    create_vpn_ipsets_item "${WGS_ENABLE}" "${WIREGUARD_CLIENT_IP_SET}"
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
}

get_balance_vpn_item() {
    iptables -t mangle -L balance 2> /dev/null | grep -qw "${1}" && return "0"
    return "1"
}

delete_balance_vpn_item() {
    local number="$( iptables -t mangle -L balance -v -n --line-numbers 2> /dev/null \
            | grep -w "${1}" | cut -d " " -f 1 | grep '^[0-9]*' | sort -nr )"
    [ -z "${number}" ] && return
    local item_no=
    for item_no in ${number}
    do
        iptables -t mangle -D balance "${item_no}" > /dev/null 2>&1
    done
}

add_balance_vpn_item() {
    if [ "${1}" = "1" ]; then
        if ! get_balance_vpn_item "${2}"; then
            iptables -t mangle -I balance -m set "${MATCH_SET}" "${2}" dst -j RETURN > /dev/null 2>&1
            if [ "${VPN_WAN_PORT}" = "0" ] || [ "${VPN_WAN_PORT}" = "1" ]; then
                iptables -t mangle -I balance -m set "${MATCH_SET}" "${2}" src -j RETURN > /dev/null 2>&1
            fi
        fi
    elif get_balance_vpn_item "${2}"; then
        delete_balance_vpn_item "${2}"
    fi
}

create_balance_vpn_items() {
    get_match_set
    add_balance_vpn_item "${OVPN_SERVER_ENABLE}" "${OVPN_SUBNET_IP_SET}"
    add_balance_vpn_item "${PPTPD_ENABLE}" "${PPTP_CLIENT_IP_SET}"
    add_balance_vpn_item "${IPSEC_SERVER_ENABLE}" "${IPSEC_SUBNET_IP_SET}"
    add_balance_vpn_item "${WGS_ENABLE}" "${WIREGUARD_CLIENT_IP_SET}"
}

init_vpn_ipsets() {
    echo "${ROUTE_LIST}" | awk '/tun|tap/ {system("'"ipset -q add ${OVPN_SUBNET_IP_SET} "'"$1)}'
    echo "${ROUTE_LIST}" | awk '/pptp/ {system("'"ipset -q add ${PPTP_CLIENT_IP_SET} "'"$1)}'
    echo "${IPSEC_SUBNET_LIST}" | awk '$1 ~ /([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}/ {system("'"ipset -q add ${IPSEC_SUBNET_IP_SET} "'"$1)}'
    echo "${ROUTE_LIST}" | awk '/wgs/ {system("'"ipset -q add ${WIREGUARD_CLIENT_IP_SET} "'"$1)}'
    clear_vpn_ipsets
}

set_balance_vpn_rule() {
    get_balance_chain || { clear_vpn_ipsets && return; }
    create_vpn_ipsets
    create_balance_vpn_items
    init_vpn_ipsets
}

print_status() {
    local vpn_item="Primary WAN"
    [ "${WAN_ACCESS_PORT}" = "1" ] && vpn_item="Secondary WAN"
    {
        echo "$(lzdate)" [$$]: -----------------------------------------------
        echo "$(lzdate)" [$$]: "   WAN Access Host Port: ${vpn_item}"
    } | tee -ai "${SYSLOG}" 2> /dev/null

    vpn_item="System Allocation"
    [ "${VPN_WAN_PORT}" = "0" ] && vpn_item="Primary WAN"
    [ "${VPN_WAN_PORT}" = "1" ] && vpn_item="Secondary WAN"
    {
        echo "$(lzdate)" [$$]: "   VPN Client WAN Port: ${vpn_item}"
        echo "$(lzdate)" [$$]: "   Polling Detection Time: ${POLLING_TIME}s"
        echo "$(lzdate)" [$$]: -----------------------------------------------
    } | tee -ai "${SYSLOG}" 2> /dev/null

    local index="0"
    for vpn_item in $( echo "${ROUTE_LIST}" | awk '/tun|tap/ {print $1":"$3}' )
    do
        let index++
        echo "$(lzdate)" [$$]: "   OpenVPN Subnet ${index}: ${vpn_item/:/ }" | tee -ai "${SYSLOG}" 2> /dev/null
    done
    [ "${index}" = "0" ] && echo "$(lzdate)" [$$]: "   OpenVPN Server: Stopped" | tee -ai "${SYSLOG}" 2> /dev/null
    echo "$(lzdate)" [$$]: ----------------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null

    if [ "${PPTPD_ENABLE}" = "1" ]; then
        vpn_item="$( nvram get pptpd_clients | sed 's/-/~/g' | sed -n 1p )"
        [ -n "${vpn_item}" ] && echo "$(lzdate)" [$$]: "   PPTP Client IP Pool: ${vpn_item}" | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    index="0"
    for vpn_item in $( echo "${ROUTE_LIST}" | awk '/pptp/ {print $1":"$3}' )
    do
        let index++
        echo "$(lzdate)" [$$]: "   PPTP Client ${index}: ${vpn_item/:/ }" | tee -ai "${SYSLOG}" 2> /dev/null
    done
    if [ "${index}" = "0" ]; then
        [ "${PPTPD_ENABLE}" = "0" ] && echo "$(lzdate)" [$$]: "   PPTP VPN Server: Stopped" | tee -ai "${SYSLOG}" 2> /dev/null
        [ "${PPTPD_ENABLE}" = "1" ] && echo "$(lzdate)" [$$]: "   PPTP VPN Client: None" | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    [ -n "${PPTPD_ENABLE}" ] && echo "$(lzdate)" [$$]: ----------------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null

    if [ -n "${IPSEC_SUBNET_LIST}" ]; then
        index="0"
        for vpn_item in $( echo "${IPSEC_SUBNET_LIST}" | awk '$1 ~ /([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}/ {print $1":ipsec"}' )
        do
            let index++
            echo "$(lzdate)" [$$]: "   IPSec VPN Subnet ${index}: ${vpn_item/:/ }" | tee -ai "${SYSLOG}" 2> /dev/null
        done
    else
        [ "${IPSEC_SERVER_ENABLE}" = "0" ] && echo "$(lzdate)" [$$]: "   IPSec VPN Server: Stopped" | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    [ -n "${IPSEC_SERVER_ENABLE}" ] && echo "$(lzdate)" [$$]: ----------------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null

    index="0"
    for vpn_item in $( echo "${ROUTE_LIST}" | awk '/wgs/ {print $1":"$3}' )
    do
        let index++
        echo "$(lzdate)" [$$]: "   WireGuard Client ${index}: ${vpn_item/:/ }" | tee -ai "${SYSLOG}" 2> /dev/null
    done
    if [ "${index}" = "0" ]; then
        [ "${WGS_ENABLE}" = "0" ] && echo "$(lzdate)" [$$]: "   WireGuard Server: Stopped" | tee -ai "${SYSLOG}" 2> /dev/null
        [ "${WGS_ENABLE}" = "1" ] && echo "$(lzdate)" [$$]: "   WireGuard Client: None" | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    [ -n "${WGS_ENABLE}" ] && echo "$(lzdate)" [$$]: ----------------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null
}

# -------------- Script Execution ---------------

set_lock

get_data || {
    LZ_VERSION=v1.0.5
    WAN_ACCESS_PORT=0
    VPN_WAN_PORT=0
    POLLING_TIME=3
    WAN0=100
    WAN1=200
    IP_RULE_PRIO_VPN=998
    OVPN_SUBNET_IP_SET="lzvpns_ovpn_subnet"
    PPTP_CLIENT_IP_SET="lzvpns_pptp_client"
    IPSEC_SUBNET_IP_SET="lzvpns_ipsec_subnet"
    WIREGUARD_CLIENT_IP_SET="lzvpns_wireguard_client"
    SYSLOG="/tmp/syslog.log"
}

cleaning_user_data

[ "${HAMMER}" != "${PATH_TMP%/*}/interface" ] && {
    {
        echo "$(lzdate)" [$$]:
        echo "$(lzdate)" [$$]: -----------------------------------------------
        echo "$(lzdate)" [$$]: Running LZ VPNS Event Handling Process "${LZ_VERSION}"
    } | tee -ai "${SYSLOG}" 2> /dev/null
}

while true
do
    delte_vpn_rules
    detect_dual_wan || break
    get_route_list || break
    get_vpn_server_status
    set_vpn_sub_route
    set_vpn_rule
    set_balance_vpn_rule
    print_status
    break
done

unset_lock

[ "${HAMMER}" != "${PATH_TMP%/*}/interface" ] && {
    echo "$(lzdate)" [$$]: | tee -ai "${SYSLOG}" 2> /dev/null
}

exit "0"

# END
