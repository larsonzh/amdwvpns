#!/bin/sh
# lzvpnsd.sh v1.0.5
# By LZ (larsonzhang@gmail.com)

# LZ VPNS script for asuswrt/merlin based router

# VPN daemon script

# BEIGIN

# --------------- Global Variable ---------------

PATH_INTERFACE="${0%/*}"
[ "${PATH_INTERFACE:0:1}" != '/' ] && PATH_INTERFACE="$( pwd )${PATH_INTERFACE#*.}"
PATH_TMP="${PATH_INTERFACE%/*}/tmp"
PATH_INTERFACE="${PATH_INTERFACE%/*}/interface"
VPN_DAEMON_DATA_FILE="lzvpnsd.dat"

# ------------- Data Exchange Area --------------
TRANSDATA=">>>>>>>>>>>>"
# -----------------------------------------------


# ------------------ Function -------------------

get_trsta() { echo "${TRANSDATA}" | awk -F '>' '{print $"'"${1}"'"}'; }

get_transdata() {
    [ "${TRANSDATA}" ] || return "1"
    echo "${TRANSDATA}" | grep -qE '^[>]|[>][>]' && return "1"
    POLLING_TIME="$( get_trsta "1" )"
    WAN0="$( get_trsta "2" )"
    WAN1="$( get_trsta "3" )"
    VPN_EVENT_INTERFACE_SCRIPTS="$( get_trsta "4" )"
    PPTP_CLIENT_IP_SET="$( get_trsta "5" )"
    IPSEC_SUBNET_IP_SET="$( get_trsta "6" )"
    WIREGUARD_CLIENT_IP_SET="$( get_trsta "7" )"
    VPN_DAEMON_IP_SET_LOCK="$( get_trsta "8" )"
    return "0"
}

get_exta() { echo "${1}" | awk -F '>' 'NR=="'"${2}"'" {print $1}'; }

get_exdata() {
    [ ! -f "${PATH_TMP}/${VPN_DAEMON_DATA_FILE}" ] && return "1"
    local data_buf="$( cat "${PATH_TMP}/${VPN_DAEMON_DATA_FILE}" 2> /dev/null )"
    [ "${data_buf}" ] || return "1"
    POLLING_TIME="$( get_exta "${data_buf}" "1" )"
    WAN0="$( get_exta "${data_buf}" "2" )"
    WAN1="$( get_exta "${data_buf}" "3" )"
    VPN_EVENT_INTERFACE_SCRIPTS="$( get_exta "${data_buf}" "4" )"
    PPTP_CLIENT_IP_SET="$( get_exta "${data_buf}" "5" )"
    IPSEC_SUBNET_IP_SET="$( get_exta "${data_buf}" "6" )"
    WIREGUARD_CLIENT_IP_SET="$( get_exta "${data_buf}" "7" )"
    VPN_DAEMON_IP_SET_LOCK="$( get_exta "${data_buf}" "8" )"
    return "0"
}

get_data() {
    get_exdata && return "0"
    get_transdata && return "0"
    return "1"
}

update_vpn_client_sub_route() {
    local vpn_client_list="$( ip route show | awk '$0 ~ "'"${1}"'" {print $1}' )"
    if [ -n "${vpn_client_list}" ]; then
        local vpn_client=""
        local vpn_client_sub_list="$( ip route show table "${WAN0}" | awk '$0 ~ "'"${1}"'" {print $1}' )"
        if [ -n "${vpn_client_sub_list}" ]; then
            for vpn_client in ${vpn_client_list}
            do
                vpn_client="$( echo "${vpn_client_sub_list}" | grep "^${vpn_client}$" )"
                [ -z "${vpn_client}" ] && break
            done
            if [ -n "${vpn_client}" ]; then
                vpn_client_sub_list="$( ip route show table "${WAN1}" | awk '$0 ~ "'"${1}"'" {print $1}' )"
                if [ -n "${vpn_client_sub_list}" ]; then
                    for vpn_client in ${vpn_client_list}
                    do
                        vpn_client="$( echo "${vpn_client_sub_list}" | grep "^${vpn_client}$" )"
                        [ -z "${vpn_client}" ] && break
                    done
                else
                    vpn_client=""
                fi
            fi
        fi
        if [ -z "${vpn_client}" ]; then
            [ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && /bin/sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
        else
            for vpn_client in $( ipset -q -L "${2}" | grep -Eo '([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}' )
            do
                if ! echo "${vpn_client_list}" | grep -q "^${vpn_client}$"; then
                    [ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && /bin/sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
                    break
                fi
            done
        fi
    else
        ipset -q -L "${2}" | grep -qE '([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}' \
            && [ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && /bin/sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
    fi
}


# -------------- Script Execution ---------------

PPTPD_ENABLE="$( nvram get pptpd_enable )"
IPSEC_SERVER_ENABLE="$( nvram get ipsec_server_enable )"
WGS_ENABLE="$( nvram get "wgs_enable" )"

[ -z "${WGS_ENABLE}" ] && [ "${PPTPD_ENABLE}" != "1" ] && [ "${IPSEC_SERVER_ENABLE}" != "1" ] && exit "1"

get_data || {
    POLLING_TIME=3
    WAN0=100
    WAN1=200
    VPN_EVENT_INTERFACE_SCRIPTS="lzvpnse.sh"
    PPTP_CLIENT_IP_SET="lzvpns_pptp_client"
    IPSEC_SUBNET_IP_SET="lzvpns_ipsec_subnet"
    WIREGUARD_CLIENT_IP_SET="lzvpns_wireguard_client"
    VPN_DAEMON_IP_SET_LOCK="lzvpns_daemon_lock"
}

! echo "${1}" | grep -qE '^[1-9]$|^[1][0]$' && exit "1"
POLLING_TIME="${1}s"

ipset -q create "${VPN_DAEMON_IP_SET_LOCK}" list:set

while [ -n "$( ipset -q -L -n "${VPN_DAEMON_IP_SET_LOCK}" )" ]
do
    [ ! -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && break
    if [ "${WGS_ENABLE}" = "1" ]; then
        WGS_ENABLE="$( nvram get "wgs_enable" )"
        [ "${WGS_ENABLE}" = "0" ] && [ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] \
            && /bin/sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
        [ "${WGS_ENABLE}" = "1" ] && update_vpn_client_sub_route "wgs" "${WIREGUARD_CLIENT_IP_SET}"
    elif [ "${WGS_ENABLE}" = "0" ]; then
        WGS_ENABLE="$( nvram get "wgs_enable" )"
        [ "${WGS_ENABLE}" = "1" ] && [ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] \
            && /bin/sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
        [ "${WGS_ENABLE}" = "0" ] && update_vpn_client_sub_route "wgs" "${WIREGUARD_CLIENT_IP_SET}"
    fi
    if [ "${PPTPD_ENABLE}" = "1" ]; then
        PPTPD_ENABLE="$( nvram get "pptpd_enable" )"
        [ "${PPTPD_ENABLE}" = "0" ] && [ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] \
            && /bin/sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
        [ "${PPTPD_ENABLE}" = "1" ] && update_vpn_client_sub_route "pptp" "${PPTP_CLIENT_IP_SET}"
    fi
    if [ "${IPSEC_SERVER_ENABLE}" = "1" ]; then
        IPSEC_SERVER_ENABLE="$( nvram get "ipsec_server_enable" )"
        [ "${IPSEC_SERVER_ENABLE}" = "0" ] && [ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] \
            && /bin/sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
    elif ipset -q -L "${IPSEC_SUBNET_IP_SET}" | grep -qE '([0-9]{1,3}[\.]){3}[0-9]{1,3}([\/][0-9]{1,2}){0,1}'; then
        [ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && /bin/sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
    fi
    [ -z "${WGS_ENABLE}" ] && [ "${PPTPD_ENABLE}" != "1" ] && [ "${IPSEC_SERVER_ENABLE}" != "1" ] && break
    eval sleep "${POLLING_TIME}"
done

ipset -q destroy "${VPN_DAEMON_IP_SET_LOCK}"

exit "0"

# END
