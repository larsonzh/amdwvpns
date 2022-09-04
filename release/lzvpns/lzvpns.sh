#!/bin/sh
# lzvpns.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# LZ script for asuswrt/merlin based router

# Script command (e.g., in the lzvpns Directory)
# Start/Restart         ./lzvpns.sh
# Stop                  ./lzvpns.sh stop
# Forced Unlocking      ./lzvpns.sh unlock


# Main execution script

# BEIGIN

#  ------------- User Defined Data --------------

# The router port used by the VPN client to access the router from the WAN 
# using the domain name or IP address。
# 0--Primary WAN (Default), 1--Secondary WAN
WAN_ACCESS_PORT=0

# The router port used by the VPN client to access the WAN through the router.
# 0--Primary WAN (Default), 1--Secondary WAN, Other--System Allocation
VPN_WAN_PORT=0

# Polling time to detect VPN client access.
# 1~10s (The default is 5 seconds)
POLLING_TIME=5


# --------------- Global Variable ---------------

LZ_VERSION=v0.0.1

# System event log file
SYSLOG="/tmp/syslog.log"

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

# Project file deployment path
PATH_BOOTLOADER="/jffs/scripts"
PATH_LZ="${0%/*}"
[ "${PATH_LZ:0:1}" != '/' ] && PATH_LZ="$( pwd )${PATH_LZ#*.}"
PATH_INTERFACE="${PATH_LZ}/interface"
PATH_DAEMON="${PATH_LZ}/daemon"
PATH_TMP="${PATH_LZ}/tmp"

# Router WAN port routing table ID
WAN0=100; WAN1=200;

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

# VPN daemon lock
VPN_DAEMON_IP_SET_LOCK="lzvpns_daemon_lock"

# Start VPN daemon time task ID
START_DAEMON_TIMEER_ID="lzvpns_start_daemon_id"

HARDWARE_TYPE=$( uname -m )
MATCH_SET='--match-set'

# Script Commands
HAMMER="$( echo "${1}" | tr [:upper:] [:lower:] )"
STOP_RUN="stop"
FORCED_UNLOCKING="unlock"

PARAM_TOTAL="${#}"

PATH_LOCK="/var/lock"
LOCK_FILE="${PATH_LOCK}/lzvpns.lock"
LOCK_FILE_ID=555
INSTANCE_LIST="${PATH_LOCK}/lzvpns_instance.lock"


# ------------------ Function -------------------

lzdate() { echo "$( date +"%F %T" )"; }

cleaning_user_data() {
    [ "${1}" != "1" ] && {
        local str="Primary WAN *"
        [ "${WAN_ACCESS_PORT}" = "0" ] && str="Primary WAN"
        [ "${WAN_ACCESS_PORT}" = "1" ] && str="Secondary WAN"
        echo $(lzdate) [$$]: WAN Access Port: "${str}" | tee -ai "${SYSLOG}" 2> /dev/null
        str="System Allocation"
        [ "${VPN_WAN_PORT}" = "0" ] && str="Primary WAN"
        [ "${VPN_WAN_PORT}" = "1" ] && str="Secondary WAN"
        echo $(lzdate) [$$]: VPN WAN Port: "${str}" | tee -ai "${SYSLOG}" 2> /dev/null
        str="5s"
        [ "${POLLING_TIME}" -ge "0" -a "${POLLING_TIME}" -le "10" ] && srt="${POLLING_TIME}s"
        echo $(lzdate) [$$]: Polling Time: "${str}" | tee -ai "${SYSLOG}" 2> /dev/null
    }
    [ "${WAN_ACCESS_PORT}" -lt "0" -o "${WAN_ACCESS_PORT}" -gt "1" ] && WAN_ACCESS_PORT=0
    [ "${POLLING_TIME}" -lt "0" -o "${POLLING_TIME}" -gt "10" ] && POLLING_TIME=5
}

clear_daemon() {
    local buffer="$( ps | grep "${VPN_DAEMON_SCRIPTS}" | grep -v grep | awk '{print $1}' )"
    [ -z "$( echo "${buffer}" )" -a -z "$( ipset -q -L -n "${VPN_DAEMON_IP_SET_LOCK}" )" ] && {
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: No VPN daemon of this script is running. | tee -ai "${SYSLOG}" 2> /dev/null
        return
    }
    ipset -q destroy "${VPN_DAEMON_IP_SET_LOCK}"
    echo "${buffer}" | xargs kill -9 > /dev/null 2>&1
    [ "${1}" != "1" ] && echo $(lzdate) [$$]: The running VPN daemon of this script in the system has been cleared. | tee -ai "${SYSLOG}" 2> /dev/null
}

clear_time_task() {
    [ -z "$( cru l | grep "#${START_DAEMON_TIMEER_ID}#" )" ] && {
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: No scheduled tasks for this script are running. | tee -ai "${SYSLOG}" 2> /dev/null
        return
    }
    cru d "${START_DAEMON_TIMEER_ID}" > /dev/null 2>&1
    sleep 1s
    rm -f "${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}" > /dev/null 2>&1
    [ "${1}" != "1" ] && echo $(lzdate) [$$]: The running scheduled tasks of this script have been cleared. | tee -ai "${SYSLOG}" 2> /dev/null
}

delte_ip_rules() {
    local buffer="$( ip rule list | grep -wo "^${1}" )"
    [ -z "$( echo "${buffer}" )" ] && return 1
    echo "${buffer}" | awk '{print "ip rule del prio "$1} END{print "ip route flush cache"}' \
        | awk '{system($0" > /dev/null 2>&1")}'
    return 0
}

restore_ip_rules() {
    delte_ip_rules "${IP_RULE_PRIO_VPN}"
    local retval="${?}"
    if [ "${1}" != "1" ]; then
        [ "${retval}" = "0" ] \
            && echo $(lzdate) [$$]: All VPN rules with priority "${IP_RULE_PRIO_VPN}" in the policy routing database have been deleted. | tee -ai "${SYSLOG}" 2> /dev/null \
            || echo $(lzdate) [$$]: None of VPN rule with priority "${IP_RULE_PRIO_VPN}" in the policy routing database. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    delte_ip_rules "${IP_RULE_PRIO_HOST}"
    retval="${?}"
    if [ "${1}" != "1" ]; then
        [ "${retval}" = "0" ] \
            && echo $(lzdate) [$$]: The WAN access router port rules with the priority of "${IP_RULE_PRIO_HOST}" in the policy routing database have been deleted. | tee -ai "${SYSLOG}" 2> /dev/null \
            || echo $(lzdate) [$$]: None of WAN access router port rule with priority of "${IP_RULE_PRIO_HOST}" in the policy routing database. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
}

restore_sub_routing_table() {
    local buffer="$( ip route list table "${1}" | grep -E 'pptp|tap|tun' )"
    [ -z "$( echo "${buffer}" )" ] && return 1
    echo "${buffer}" \
        | awk '{print "ip route del "$0"'" table ${1}"'"}  END{print "ip route flush cache"}' \
        | awk '{system($0" > /dev/null 2>&1")}'
    return 0
}

restore_routing_table() {
    [ -z "$( ip route list| grep nexthop )" ] && {
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: WAN0/WAN1 routing table is empty. | tee -ai "${SYSLOG}" 2> /dev/null
        return
    }
    restore_sub_routing_table "${WAN0}"
    local retval="${?}"
    if [ "${1}" != "1" ]; then
        [ "${retval}" = "0" ] \
            && echo $(lzdate) [$$]: VPN routing data in WAN0 routing table has been cleared. | tee -ai "${SYSLOG}" 2> /dev/null \
            || echo $(lzdate) [$$]: None of VPN routing data in the WAN0 routing table. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    restore_sub_routing_table "${WAN1}"
    retval="${?}"
    if [ "${1}" != "1" ]; then
        [ "${retval}" = "0" ] \
            && echo $(lzdate) [$$]: VPN routing data in WAN1 routing table has been cleared. | tee -ai "${SYSLOG}" 2> /dev/null \
            || echo $(lzdate) [$$]: None of VPN routing data in the WAN1 routing table. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
}

restore_balance_chain() {
    [ -z "$( iptables -t mangle -L PREROUTING 2> /dev/null | grep balance )" ] && return
    local number="$( iptables -t mangle -L balance -v -n --line-numbers 2> /dev/null \
            | grep -Ew "${OVPN_SUBNET_IP_SET}|${PPTP_CLIENT_IP_SET}|$IPSEC_SUBNET_IP_SET}" \
            | cut -d " " -f 1 | grep '^[0-9]*' | sort -nr )"
    [ -z "${number}" ] && {
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: None of VPN item in the balance chain. | tee -ai "${SYSLOG}" 2> /dev/null
        return
    }
    local item_no=
    for item_no in ${number}
    do
        iptables -t mangle -D balance "${item_no}" > /dev/null 2>&1
    done
    [ "${1}" != "1" ] && echo $(lzdate) [$$]: All VPN items in the balance chain have been cleared. | tee -ai "${SYSLOG}" 2> /dev/null
}

clear_ipsets() {
    [ -z "$( ipset -q -L -n "${OVPN_SUBNET_IP_SET}" -a -z "$( ipset -q -L -n "${PPTP_CLIENT_IP_SET}" -a -z "$( ipset -q -L -n "${IPSEC_SUBNET_IP_SET}" ] {
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: None of VPN data set of this script residing in the system memory. | tee -ai "${SYSLOG}" 2> /dev/null
        return
    }
    ipset -q flush "${OVPN_SUBNET_IP_SET}" && ipset -q destroy "${OVPN_SUBNET_IP_SET}"
    ipset -q flush "${PPTP_CLIENT_IP_SET}" && ipset -q destroy "${PPTP_CLIENT_IP_SET}"
    ipset -q flush "${IPSEC_SUBNET_IP_SET}" && ipset -q destroy "${IPSEC_SUBNET_IP_SET}"
    [ "${1}" != "1" ] && echo $(lzdate) [$$]: All VPN data sets of this script residing in the system memory have been cleared. | tee -ai "${SYSLOG}" 2> /dev/null
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
    [ "${1}" != "1" ] && echo $(lzdate) [$$]: The application directory for this script has been reinitialized. | tee -ai "${SYSLOG}" 2> /dev/null
}

clear_event_interface() {
    [ ! -f "${PATH_BOOTLOADER}/${1}" ] && return 1
    [ -z "$( grep "${2}" "${PATH_BOOTLOADER}/${1}" 2> /dev/null )" ] && return 2
    sed -i "/"${2}"/d" "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
    return 0
}

check_file() {
    local scripts_file_exist=0
    [ ! -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && {
        echo $(lzdate) [$$]: "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" does not exist. | tee -ai "${SYSLOG}" 2> /dev/null
        scripts_file_exist=1
    }
    [ ! -f "${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS}" ] && {
        echo $(lzdate) [$$]: "${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS}" does not exist. | tee -ai "${SYSLOG}" 2> /dev/null
        scripts_file_exist=1
    }
    if [ "$scripts_file_exist" = 1 ]; then
        clear_event_interface "$VPN_EVENT_FILE" "${VPN_EVENT_INTERFACE_SCRIPTS}"
        [ "${?}" = "0" -a "${1}" != "1" ] && echo $(lzdate) [$$]: Successfully uninstalled VPN event interface. | tee -ai "${SYSLOG}" 2> /dev/null
        clear_event_interface "$BOOTLOADER_FILE" "${PROJECT_ID}"
        [ "${?}" = "0" -a "${1}" != "1" ] && echo $(lzdate) [$$]: Uninstallation script started boot event interface successfully. | tee -ai "${SYSLOG}" 2> /dev/null
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: Dual WAN VPN support service can\'t be started. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    fi
    [ "${1}" != "1" ] && echo $(lzdate) [$$]: Script files are located in the specified directory location. | tee -ai "${SYSLOG}" 2> /dev/null
    return 0
}

update_data_item() {
    local data_item="$( grep -wo "${1}=.$" "${2}" > /dev/null 2>&1 | sed 's/\"//g' )"
    [ -z "$( echo "${data_item}" )" ] && return 1
    [ "${data_item#*=}" != "${${1}}" ] && {
        sed -i "s:"${1}"=.*$:"${1}"=\""${"${1}"}"\":g" "${2}" > /dev/null 2>&1
        data_item="$( grep -wo "${1}=.$" "${2}" > /dev/null 2>&1 | sed 's/\"//g' )"
        [ "${data_item#*=}" != "${${1}}" ] && return 3
        return 2
    }
    return 0
}

consistency_update() {
    update_data_item "${1}" "${2}"
    local retval="${?}"
    if [ "${retval}" = "1" ]; then
        [ "${4}" != "1" ] && {
            echo $(lzdate) [$$]: Missing data item "${1}" in VPN "${3}" script file. | tee -ai "${SYSLOG}" 2> /dev/null
            echo $(lzdate) [$$]: Data item consistency confirmation in VPN "${3}" script file failed. | tee -ai "${SYSLOG}" 2> /dev/null
            echo $(lzdate) [$$]: Dual WAN VPN support service can\'t be started. | tee -ai "${SYSLOG}" 2> /dev/null
        }
        return 1
    elif [ "${retval}" = "2" ]; then
        [ "${4}" != "1" ] && echo $(lzdate) [$$]: The data item "${1}" in VPN "${3}" script file has been updated. | tee -ai "${SYSLOG}" 2> /dev/null
    elif [ "${retval}" = "3" ]; then
        [ "${4}" != "1" ] && {
            echo $(lzdate) [$$]: Update of data item "${1}" in VPN "${3}" script file failed. | tee -ai "${SYSLOG}" 2> /dev/null
            echo $(lzdate) [$$]: Dual WAN VPN support service can\'t be started. | tee -ai "${SYSLOG}" 2> /dev/null
        }
        return 1
    fi
    [ "${4}" != "1" ] && echo $(lzdate) [$$]: All data items in VPN "${3}" script file have passed the consistency confirmation. | tee -ai "${SYSLOG}" 2> /dev/null
    return 0
}

update_data() {
    local transdata=""${VPN_WAN_PORT}">"${WAN0}">"${WAN1}">"${IP_RULE_PRIO_VPN}">"${OVPN_SUBNET_IP_SET}">"${PPTP_CLIENT_IP_SET}">"${IPSEC_SUBNET_IP_SET}">"${SYSLOG}""
    consistency_update "TRANSDATA" "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" "event processing"
    [ "${?}" = "1" ] && return 1

    transdata=""${POLLING_TIME}">"${WAN0}">"${WAN1}">"${VPN_EVENT_INTERFACE_SCRIPTS}">"${PPTP_CLIENT_IP_SET}">"${IPSEC_SUBNET_IP_SET}">"${VPN_DAEMON_IP_SET_LOCK}""
    consistency_update "TRANSDATA" "${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS}" "daemon"
    [ "${?}" = "1" ] && return 1

    returo 0
}

set_wan_access_port() {
    [ "${WAN_ACCESS_PORT}" != "0" -a "{$WAN_ACCESS_PORT}" != "1" ] && return 2
    local router_local_ip="$( echo $( ifconfig br0 2> /dev/null ) | awk '{print $7}' | awk -F: '{print $2}' )"
    [ -z "${router_local_ip}" ] && {
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: Unable to get local IP of router host. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    }
    local access_wan="${WAN0}"
    [ "${WAN_ACCESS_PORT}" = "1" ] && access_wan="${WAN1}"
    ip rule add from all to "${router_local_ip}" table "${access_wan}" prio "${IP_RULE_PRIO_HOST}" > /dev/null 2>&1
    ip rule add from "${router_local_ip}" table "${access_wan}" prio "${IP_RULE_PRIO_HOST}" > /dev/null 2>&1
    ip route flush cache > /dev/null 2>&1
    if [ -n "$( ip rule list prio "${IP_RULE_PRIO_HOST}" | grep -v all | grep "${router_local_ip}" )" \
        -a -n "( ip rule list prio "${IP_RULE_PRIO_HOST}" | grep all | grep "${router_local_ip}" )" ]; then
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: WAN access port has been set successfully. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        [ "${1}" != "1" ] &&  echo $(lzdate) [$$]: WAN access port configuration failed. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    fi
    return 0
}

create_vpn_ipsets() {
    ipset -! create "${OVPN_SUBNET_IP_SET}" nethash; ipset -q flush "${OVPN_SUBNET_IP_SET}";
    ipset -! create "${PPTP_CLIENT_IP_SET}" nethash; ipset -q flush "${PPTP_CLIENT_IP_SET}";
    ipset -! create "${IPSEC_SUBNET_IP_SET}" nethash; ipset -q flush "${IPSEC_SUBNET_IP_SET}";
}

get_match_set() {
    case ${HARDWARE_TYPE} in
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

set_balance_chain() {
    [ -z "$( iptables -t mangle -L PREROUTING 2> /dev/null | grep balance )" ] && return
    create_vpn_ipsets
    get_match_set
    iptables -t mangle -I balance -m set "${MATCH_SET}" "${OVPN_SUBNET_IP_SET}" dst -j RETURN > /dev/null 2>&1
    iptables -t mangle -I balance -m set "${MATCH_SET}" "${PPTP_CLIENT_IP_SET}" dst -j RETURN > /dev/null 2>&1
    iptables -t mangle -I balance -m set "${MATCH_SET}" "${IPSEC_SUBNET_IP_SET}" dst -j RETURN > /dev/null 2>&1
    if [ "${VPN_WAN_PORT}" = 0 -o "${VPN_WAN_PORT}" = 1 ]; then
        iptables -t mangle -I balance -m set "${MATCH_SET}" "${OVPN_SUBNET_IP_SET}" src -j RETURN > /dev/null 2>&1
        iptables -t mangle -I balance -m set "${MATCH_SET}" "${PPTP_CLIENT_IP_SET}" src -j RETURN > /dev/null 2>&1
        iptables -t mangle -I balance -m set "${MATCH_SET}" "${IPSEC_SUBNET_IP_SET}" src -j RETURN > /dev/null 2>&1
    fi
}

craeate_daemon_start_scripts() {
    cat > "${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}" <<EOF_START_DAEMON_SCRIPT
# ${VPN_DAEMON_START_SCRIPT} ${LZ_VERSION}
# By LZ (larsonzhang@gmail.com)
# Do not manually modify!!!

[ ! -d "${PATH_LOCK}" ] && { mkdir -p "${PATH_LOCK}" > /dev/null 2>&1; chmod 777 "${PATH_LOCK}" > /dev/null 2>&1; }
exec $LOCK_FILE_ID<>"${LOCK_FILE}"; flock -x "${LOCK_FILE_ID}" > /dev/null 2>&1;

ipset -q destroy "${VPN_DAEMON_IP_SET_LOCK}"
ps | grep "${VPN_DAEMON_SCRIPTS}" | grep -v grep | awk '{print \$1}' | xargs kill -9 > /dev/null 2>&1
nohup sh "${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS}" "${POLLING_TIME}" > /dev/null 2>&1 &
sleep 1s
if [ -n "\$( ps | grep "${VPN_DAEMON_SCRIPTS}" | grep -v grep )" ]; then
    cru d "${START_DAEMON_TIMEER_ID}" > /dev/null 2>&1
    sleep 1s
    rm -f "${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}" > /dev/null 2>&1
    lzdate() { echo "\$( date +"%F %T" )"; }
    echo \$(lzdate) [\$\$]: >> "${SYSLOG}" 2> /dev/null
    echo \$(lzdate) [\$\$]: ----------------------------------------------- >> "${SYSLOG}" 2> /dev/null
    echo \$(lzdate) [\$\$]: The VPN daemon has been started again. >> "${SYSLOG}" 2> /dev/null
    echo \$(lzdate) [\$\$]: ----------- LZ "$LZ_VERSION" VPN Daemon -------------- >> "${SYSLOG}" 2> /dev/null
    echo \$(lzdate) [\$\$]: >> "${SYSLOG}" 2> /dev/null
fi

flock -u "${LOCK_FILE_ID}" > /dev/null 2>&1

EOF_START_DAEMON_SCRIPT
    chmod +x "${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}" > /dev/null 2>&1
}

start_daemon() {
    [ -z "$( which nohup 2> /dev/null )" ] && return
    [ "$( nvram get pptpd_enable )" != "1" -a "$( nvram get ipsec_server_enable)" != "1" ] && return

    nohup sh "${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS}" "${POLLING_TIME}" > /dev/null 2>&1 &
 
    craeate_daemon_start_scripts

    [ -f "${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}" ] \
        && cru a ${START_DAEMON_TIMEER_ID} "*/1 * * * * /bin/sh ${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}" > /dev/null 2>&1

    if [ -n "$( ps | grep "${VPN_DAEMON_SCRIPTS}" | grep -v grep )" ]; then
            echo $(lzdate) [$$]: ---------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null
            echo $(lzdate) [$$]: The VPN daemon has been started. | tee -ai "${SYSLOG}" 2> /dev/null
    elif [ -n "$( cru l | grep "#${START_DAEMON_TIMEER_ID}#" )" ]; then
            echo $(lzdate) [$$]: ---------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null
            echo $(lzdate) [$$]: The VPN daemon is starting... | tee -ai "${SYSLOG}" 2> /dev/null
    fi
}

create_event_interface() {
    [ ! -d "${PATH_BOOTLOADER}" ] && mkdir -p "${PATH_BOOTLOADER}" > /dev/null 2>&1
    if [ ! -f "${PATH_BOOTLOADER}/${1}" ]; then
        cat > "${PATH_BOOTLOADER}/${1}" <<EOF_INTERFACE
#!/bin/sh
EOF_INTERFACE
    fi
    [ ! -f "${PATH_BOOTLOADER}/${1}" ] && return 1
    if [ -z "$( grep -m 1 '#!\/bin\/sh' "${PATH_BOOTLOADER}/${1}" )" ]; then
        sed -i '1i #!\/bin\/sh' "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
    else
        [ "$( grep -m 1 '.' "${PATH_BOOTLOADER}/${1}" )" != "#!/bin/sh" ] && \
            sed -i 'l1 s:^.*#!/bin/sh:#!/bin/sh:' "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
    fi
    if [ -z "$( grep "${2}/${3}" "${PATH_BOOTLOADER}/${1}" )" ]; then
        sed -i "/"${3}"/d" "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
        sed -i "\$a "${2}/${3}" # Added by LZ" "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
    fi
    chmod +x "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
    [ -z "$( grep "${2}/${3}" "${PATH_BOOTLOADER}/${1}" )" ] && return 1
    return 0
}

register_event_interface() {
    create_event_interface "${BOOTLOADER_FILE}" "${PATH_LZ}" "${MAIN_SCRIPTS}"
    if [ "${?}" = "0" ]; then
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: Successfully registered VPN event interface. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: VPN event interface registration failed. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    fi
    create_event_interface "${VPN_EVENT_FILE}" "${PATH_INTERFACE}" "${VPN_EVENT_INTERFACE_SCRIPTS}"
    if [ "${?}" = "0" ]; then
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: The script boot start event interface has been successfully registered. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: Script boot start event interface registration failed. | tee -ai "${SYSLOG}" 2> /dev/null
        clear_event_interface "$BOOTLOADER_FILE" "${PROJECT_ID}"
        [ "${?}" = "0" -a "${1}" != "1" ] && echo $(lzdate) [$$]: Uninstallation script started boot event interface successfully. | tee -ai "${SYSLOG}" 2> /dev/null
        clear_daemon
        clear_time_task
        clear_daemon "1"
        restore_ip_rules
        restore_routing_table
        restore_balance_chain
        clear_ipsets
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: Dual WAN VPN Support service has stopped. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    fi
    return 0
}

init_service() {
    cleaning_user_data
    clear_daemon
    clear_time_task
    clear_daemon "1"
    restore_ip_rules
    restore_routing_table
    restore_balance_chain
    clear_ipsets
    init_directory
    check_file || return 1
    return 0
}

stop_service() {
    [ "${HAMMER}" != "${STOP_RUN}" ] && return 1
    clear_event_interface "$VPN_EVENT_FILE" "${VPN_EVENT_INTERFACE_SCRIPTS}"
    [ "${?}" = "0" -a "${1}" != "1" ] && echo $(lzdate) [$$]: Successfully uninstalled VPN event interface. | tee -ai "${SYSLOG}" 2> /dev/null
    clear_event_interface "$BOOTLOADER_FILE" "${PROJECT_ID}"
    [ "${?}" = "0" -a "${1}" != "1" ] && echo $(lzdate) [$$]: Uninstallation script started boot event interface successfully. | tee -ai "${SYSLOG}" 2> /dev/null
    [ "${1}" != "1" ] && echo $(lzdate) [$$]: Dual WAN VPN Support service has stopped. | tee -ai "${SYSLOG}" 2> /dev/null
    return 0
}

start_service() {
    update_data || return 1
    [ -z "$( ip route list | grep nexthop )" ] && return 1
    set_wan_access_port
    set_balance_chain
    sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
    start_daemon
    register_event_interface || return 1
    return 0
}

set_lock() {
    [ "${HAMMER}" = "${FORCED_UNLOCKING}" ] && return 1
    echo "lzvpns_${HAMMER}" >> "${INSTANCE_LIST}"
    [ ! -d "${PATH_LOCK}" ] && { mkdir -p "${PATH_LOCK}" > /dev/null 2>&1; chmod 777 "${PATH_LOCK}" > /dev/null 2>&1; }
    exec 555<>"${LOCK_FILE}"; flock -x "${LOCK_FILE_ID}" > /dev/null 2>&1;
    sed -i -e '/^$/d' -e '/^[ ]*$/d' -e '1d' "${INSTANCE_LIST}" > /dev/null 2>&1
    if [ "$( grep -c 'lzvpns_' "${INSTANCE_LIST}" 2> /dev/null )" -gt "0" ]; then
        local curstance="$( grep 'lzvpns_' "${INSTANCE_LIST}" 2> /dev/null | sed -n 1p | sed -e 's/^[ ]*//g' -e 's/[ ]*$//g' )"
        [ "${curstance}" = "lzvpns_${HAMMER}" ] && {
            [ "${1}" != "1" ] && echo $(lzdate) [$$]: Dual WAN VPN Support service is being started by another instance.
            return 1
        }
    fi
    return 0
}

forced_unlock() {
    rm -rf "${INSTANCE_LIST}" > /dev/null 2>&1
    if [ -f "${LOCK_FILE}" ]; then
        rm -rf "${LOCK_FILE}" > /dev/null 2>&1
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: Program synchronization lock has been successfully unlocked.
    else
        [ "${1}" != "1" ] && echo $(lzdate) [$$]: There is no program synchronization lock.
    fi
    return 0
}

unset_lock() {
    [ "${HAMMER}" = "${FORCED_UNLOCKING}" ] && forced_unlock && return
    [ "$( grep -c 'lzvpns_' "${INSTANCE_LIST}" 2> /dev/null )" -le "0" ] && \
        rm -rf "${INSTANCE_LIST}" > /dev/null 2>&1
    flock -u "${LOCK_FILE_ID}" > /dev/null 2>&1
}

command_parsing() {
    [ "${PARAM_TOTAL}" = "0" ] && return 0
    [ "${HAMMER}" != "${STOP_RUN}" -a "${HAMMER}" != "${FORCED_UNLOCKING}" ] && {
    [ "${1}" != "1" ] && echo $(lzdate) [$$]: Oh, you\'re using the wrong command. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    }
    return 0
}


# -------------- Script Execution ---------------

echo $(lzdate) [$$]: | tee -ai "${SYSLOG}" 2> /dev/null
echo $(lzdate) [$$]: LZ "${LZ_VERSION}" vpns script commands start...... | tee -ai "${SYSLOG}" 2> /dev/null
echo $(lzdate) [$$]: By LZ \(larsonzhang@gmail.com\) | tee -ai "${SYSLOG}" 2> /dev/null

while ture
do
    command_parsing || break
    set_lock || break
    init_service || break
    stop_service && break
    start_service
    break
done

unset_lock

echo $(lzdate) [$$]: LZ "${LZ_VERSION}" vpns script commands executed! | tee -ai "${SYSLOG}" 2> /dev/null
echo $(lzdate) [$$]: | tee -ai "${SYSLOG}" 2> /dev/null

exit 0

# END
