#!/bin/sh
# lzvpns.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# LZ VPNS script for asuswrt/merlin based router

# Script command (e.g., in the lzvpns Directory)
# Start/Restart Service     ./lzvpns.sh
# Stop Service              ./lzvpns.sh stop
# Forced Unlocking          ./lzvpns.sh unlock
# Uninstall                 ./uninstall.sh


# Main execution script

# BEIGIN

#  ------------- User Defined Data --------------

# The host port of the router, which is used by the VPN client when accessing the router 
# from the WAN using the domain name or IP address. 
# 0--Primary WAN (Default), 1--Secondary WAN
WAN_ACCESS_PORT=0

# The router host port used by VPN clients when accessing the WAN through the router.
# 0--Primary WAN (Default), 1--Secondary WAN, Other--System Allocation
VPN_WAN_PORT=0

# Polling time for detecting and maintaining VPN service status.
# 1~10s (The default is 3 seconds)
POLLING_TIME=3


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

# Data exchange file
VPN_DATA_FILE="lzvpnse.dat"
VPN_DAEMON_DATA_FILE="lzvpnsd.dat"

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

# Script Commands
HAMMER="$( echo "${1}" | tr '[:A-Z:]' '[:a-z:]' )"
STOP_RUN="stop"
FORCED_UNLOCKING="unlock"

PARAM_TOTAL="${#}"

PATH_LOCK="/var/lock"
LOCK_FILE="${PATH_LOCK}/lz_rule.lock"
LOCK_FILE_ID=555
INSTANCE_LIST="${PATH_LOCK}/lzvpns_instance.lock"

TRANSFER=0

# ------------------ Function -------------------

lzdate() { eval echo "$( date +"%F %T" )"; }

set_lock() {
    [ "${HAMMER}" = "${FORCED_UNLOCKING}" ] && return 1
    echo "lzvpns_${HAMMER}" >> "${INSTANCE_LIST}"
    [ ! -d "${PATH_LOCK}" ] && { mkdir -p "${PATH_LOCK}" > /dev/null 2>&1; chmod 777 "${PATH_LOCK}" > /dev/null 2>&1; }
    eval "exec ${LOCK_FILE_ID}<>${LOCK_FILE}"
    flock -x "${LOCK_FILE_ID}" > /dev/null 2>&1;
    sed -i -e '/^$/d' -e '/^[ ]*$/d' -e '1d' "${INSTANCE_LIST}" > /dev/null 2>&1
    if [ "$( grep -c 'lzvpns_' "${INSTANCE_LIST}" 2> /dev/null )" -gt "0" ]; then
        [ "$( grep 'lzvpns_' "${INSTANCE_LIST}" 2> /dev/null | sed -n 1p | sed -e 's/^[ ]*//g' -e 's/[ ]*$//g' )" = "lzvpns_${HAMMER}" ] && {
            echo "$(lzdate)" [$$]: Dual WAN VPN Support service is being started by another instance.
            return 1
        }
    fi
    return 0
}

forced_unlock() {
    rm -f "${INSTANCE_LIST}"
    if [ -f "${LOCK_FILE}" ]; then
        rm -f "${LOCK_FILE}"
        echo "$(lzdate)" [$$]: Program synchronization lock has been successfully unlocked.
    else
        echo "$(lzdate)" [$$]: There is no program synchronization lock.
    fi
    return 0
}

unset_lock() {
    [ "${HAMMER}" = "error" ] && return
    [ "${HAMMER}" = "${FORCED_UNLOCKING}" ] && forced_unlock && return
    [ "$( grep -c 'lzvpns_' "${INSTANCE_LIST}" 2> /dev/null )" -le "0" ] && \
        rm -f "${INSTANCE_LIST}"
    flock -u "${LOCK_FILE_ID}" > /dev/null 2>&1
}

command_parsing() {
    [ "${PARAM_TOTAL}" = "0" ] && return 0
    [ "${HAMMER}" = "${STOP_RUN}" ] && return 0
    [ "${HAMMER}" = "${FORCED_UNLOCKING}" ] && return 0
    HAMMER="error"
    echo "$(lzdate)" [$$]: Oh, you\'re using the wrong command. | tee -ai "${SYSLOG}" 2> /dev/null
    return 1
}

cleaning_user_data() {
    local str="Primary WAN *"
    [ "${WAN_ACCESS_PORT}" = "0" ] && str="Primary WAN"
    [ "${WAN_ACCESS_PORT}" = "1" ] && str="Secondary WAN"
    echo "$(lzdate)" [$$]: WAN Access Port: "${str}" | tee -ai "${SYSLOG}" 2> /dev/null
    str="System Allocation"
    [ "${VPN_WAN_PORT}" = "0" ] && str="Primary WAN"
    [ "${VPN_WAN_PORT}" = "1" ] && str="Secondary WAN"
    echo "$(lzdate)" [$$]: VPN WAN Port: "${str}" | tee -ai "${SYSLOG}" 2> /dev/null
    str="5s"
    [ "${POLLING_TIME}" -ge "0" ] && [ "${POLLING_TIME}" -le "10" ] && str="${POLLING_TIME}s"
    echo "$(lzdate)" [$$]: Polling Time: "${str}" | tee -ai "${SYSLOG}" 2> /dev/null
    [ "${WAN_ACCESS_PORT}" -lt "0" ] || [ "${WAN_ACCESS_PORT}" -gt "1" ] && WAN_ACCESS_PORT=0
    [ "${POLLING_TIME}" -lt "0" ] || [ "${POLLING_TIME}" -gt "10" ] && POLLING_TIME=3
}

clear_daemon() {
    local buffer="$( ps | grep "${VPN_DAEMON_SCRIPTS}" | grep -v grep | awk '{print $1}' )"
    [ -z "${buffer}" ] && [ -z "$( ipset -q -L -n "${VPN_DAEMON_IP_SET_LOCK}" )" ] && {
        [ "${1}" != "1" ] && echo "$(lzdate)" [$$]: No VPN daemon of this script is running. | tee -ai "${SYSLOG}" 2> /dev/null
        return
    }
    ipset -q destroy "${VPN_DAEMON_IP_SET_LOCK}"
    echo "${buffer}" | xargs kill -9 > /dev/null 2>&1
    [ "${1}" != "1" ] && echo "$(lzdate)" [$$]: The running VPN daemon of this script in the system has been cleared. | tee -ai "${SYSLOG}" 2> /dev/null
}

clear_time_task() {
    if ! cru l | grep -q "#${START_DAEMON_TIMEER_ID}#"; then
        echo "$(lzdate)" [$$]: No scheduled tasks for this script are running. | tee -ai "${SYSLOG}" 2> /dev/null
        return
    fi
    cru d "${START_DAEMON_TIMEER_ID}" > /dev/null 2>&1
    sleep 1s
    rm -f "${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}"
    echo "$(lzdate)" [$$]: The running scheduled tasks of this script have been cleared. | tee -ai "${SYSLOG}" 2> /dev/null
}

delte_ip_rules() {
    local buffer="$( ip rule list | grep -wo "^${1}" )"
    [ -z "${buffer}" ] && return 1
    echo "${buffer}" | awk '{print "ip rule del prio "$1} END{print "ip route flush cache"}' \
        | awk '{system($0" > /dev/null 2>&1")}'
    return 0
}

restore_ip_rules() {
    if delte_ip_rules "${IP_RULE_PRIO_VPN}"; then
        echo "$(lzdate)" [$$]: All VPN rules with priority "${IP_RULE_PRIO_VPN}" in the policy routing database have been deleted. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$(lzdate)" [$$]: None of VPN rule with priority "${IP_RULE_PRIO_VPN}" in the policy routing database. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    if delte_ip_rules "${IP_RULE_PRIO_HOST}"; then
        echo "$(lzdate)" [$$]: The WAN access router port rules with the priority of "${IP_RULE_PRIO_HOST}" in the policy routing database have been deleted. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$(lzdate)" [$$]: None of WAN access router port rule with priority of "${IP_RULE_PRIO_HOST}" in the policy routing database. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
}

restore_sub_routing_table() {
    local buffer="$( ip route list table "${1}" | grep -E 'pptp|tap|tun' )"
    [ -z "${buffer}" ] && return 1
    echo "${buffer}" \
        | awk '{print "ip route del "$0"'" table ${1}"'"}  END{print "ip route flush cache"}' \
        | awk '{system($0" > /dev/null 2>&1")}'
    return 0
}

restore_routing_table() {
    if ! ip route list | grep -q nexthop; then
        echo "$(lzdate)" [$$]: WAN0/WAN1 routing table is empty. | tee -ai "${SYSLOG}" 2> /dev/null
        return
    fi
    if restore_sub_routing_table "${WAN0}"; then
        echo "$(lzdate)" [$$]: VPN routing data in WAN0 routing table has been cleared. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$(lzdate)" [$$]: None of VPN routing data in the WAN0 routing table. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    if restore_sub_routing_table "${WAN1}"; then
        echo "$(lzdate)" [$$]: VPN routing data in WAN1 routing table has been cleared. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$(lzdate)" [$$]: None of VPN routing data in the WAN1 routing table. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
}

restore_balance_chain() {
    ! iptables -t mangle -L PREROUTING 2> /dev/null | grep -qw balance && return
    local number="$( iptables -t mangle -L balance -v -n --line-numbers 2> /dev/null \
            | grep -Ew "${OVPN_SUBNET_IP_SET}|${PPTP_CLIENT_IP_SET}|${IPSEC_SUBNET_IP_SET}" \
            | cut -d " " -f 1 | grep '^[0-9]*' | sort -nr )"
    [ -z "${number}" ] && {
        echo "$(lzdate)" [$$]: None of VPN item in the balance chain. | tee -ai "${SYSLOG}" 2> /dev/null
        return
    }
    local item_no=
    for item_no in ${number}
    do
        iptables -t mangle -D balance "${item_no}" > /dev/null 2>&1
    done
    echo "$(lzdate)" [$$]: All VPN items in the balance chain have been cleared. | tee -ai "${SYSLOG}" 2> /dev/null
}

clear_ipsets() {
    [ -z "$( ipset -q -L -n "${OVPN_SUBNET_IP_SET}" )" ] && [ -z "$( ipset -q -L -n "${PPTP_CLIENT_IP_SET}" )" ] \
        && [ -z "$( ipset -q -L -n "${IPSEC_SUBNET_IP_SET}" )" ] && {
        echo "$(lzdate)" [$$]: None of VPN data set of this script residing in the system memory. | tee -ai "${SYSLOG}" 2> /dev/null
        return
    }
    ipset -q flush "${OVPN_SUBNET_IP_SET}" && ipset -q destroy "${OVPN_SUBNET_IP_SET}"
    ipset -q flush "${PPTP_CLIENT_IP_SET}" && ipset -q destroy "${PPTP_CLIENT_IP_SET}"
    ipset -q flush "${IPSEC_SUBNET_IP_SET}" && ipset -q destroy "${IPSEC_SUBNET_IP_SET}"
    echo "$(lzdate)" [$$]: All VPN data sets of this script residing in the system memory have been cleared. | tee -ai "${SYSLOG}" 2> /dev/null
}

init_directory() {
    [ ! -d "${PATH_LZ}" ] && mkdir -p "${PATH_LZ}" > /dev/null 2>&1
    chmod 775 "${PATH_LZ}" > /dev/null 2>&1
    [ ! -d "${PATH_INTERFACE}" ] && mkdir -p "${PATH_INTERFACE}" > /dev/null 2>&1
    chmod 775 "${PATH_INTERFACE}" > /dev/null 2>&1
    [ ! -d "${PATH_TMP}" ] && mkdir -p "${PATH_TMP}" > /dev/null 2>&1
    chmod 775 "${PATH_TMP}" > /dev/null 2>&1
    cd "${PATH_INTERFACE}/" > /dev/null 2>&1 && chmod -R 775 ./* > /dev/null 2>&1
    cd "${PATH_TMP}/" > /dev/null 2>&1 && chmod -R 775 ./* > /dev/null 2>&1
    cd "${PATH_LZ}/" > /dev/null 2>&1 && chmod -R 775 ./* > /dev/null 2>&1
    echo "$(lzdate)" [$$]: The application directory for this script has been reinitialized. | tee -ai "${SYSLOG}" 2> /dev/null
}

clear_event_interface() {
    [ ! -f "${PATH_BOOTLOADER}/${1}" ] && return 1
    ! grep -q "${2}" "${PATH_BOOTLOADER}/${1}" 2> /dev/null && return 2
    sed -i "/${2}/d" "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
    return 0
}

clear_all_event_interface() {
    if clear_event_interface "$VPN_EVENT_FILE" "${VPN_EVENT_INTERFACE_SCRIPTS}"; then
        echo "$(lzdate)" [$$]: Successfully uninstalled VPN event interface. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    if clear_event_interface "$BOOTLOADER_FILE" "${PROJECT_ID}"; then
        echo "$(lzdate)" [$$]: Uninstallation script started boot event interface successfully. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    return 0
}

delete_data_file() {
    if [ -f "${PATH_TMP}/${VPN_DATA_FILE}" ]; then
        rm -f "${PATH_TMP}/${VPN_DATA_FILE}"
        echo "$(lzdate)" [$$]: Deleted VPN event data exchange file. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$(lzdate)" [$$]: No VPN event data exchange file to delete. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    if [ -f "${PATH_TMP}/${VPN_DAEMON_DATA_FILE}" ]; then
        rm -f "${PATH_TMP}/${VPN_DAEMON_DATA_FILE}"
        echo "$(lzdate)" [$$]: Deleted VPN daemon data exchange file. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$(lzdate)" [$$]: No VPN daemon data exchange file to delete. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
}

check_file() {
    while true
    do
        [ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && break
        echo "$(lzdate)" [$$]: "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" does not exist. | tee -ai "${SYSLOG}" 2> /dev/null
        [ -f "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" ] && break
        echo "$(lzdate)" [$$]: "${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS}" does not exist. | tee -ai "${SYSLOG}" 2> /dev/null
        clear_all_event_interface
        delete_data_file
        echo "$(lzdate)" [$$]: Dual WAN VPN support service can\'t be started. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    done
    echo "$(lzdate)" [$$]: Script files are located in the specified directory location. | tee -ai "${SYSLOG}" 2> /dev/null
    return 0
}

update_data_item() {
    local data_item="$( grep -E "^${1}=|^[ ]*${1}=" "${3}" 2> /dev/null )"
    [ -z "${data_item}" ] && return 1
    [ "${data_item}" != "${1}=\"${2}\"" ] && {
        sed -i "s:^.*${1}=.*$:${1}=\"${2}\":g" "${3}" > /dev/null 2>&1
        data_item="$( grep "^${1}=" "${3}" 2> /dev/null )"
        [ "${data_item#*=}" != "\"${2}\"" ] && return 3
        return 2
    }
    return 0
}

consistency_update() {
    update_data_item "${1}" "${2}" "${3}"
    local retval="${?}"
    if [ "${retval}" = "1" ]; then
        echo "$(lzdate)" [$$]: Missing data item "${1}" in VPN "${4}" script file. | tee -ai "${SYSLOG}" 2> /dev/null
        echo "$(lzdate)" [$$]: Data item consistency confirmation in VPN "${4}" script file failed. | tee -ai "${SYSLOG}" 2> /dev/null
        echo "$(lzdate)" [$$]: Dual WAN VPN support service can\'t be started. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    elif [ "${retval}" = "2" ]; then
        echo "$(lzdate)" [$$]: The data item "${1}" in VPN "${4}" script file has been updated. | tee -ai "${SYSLOG}" 2> /dev/null
    elif [ "${retval}" = "3" ]; then
        echo "$(lzdate)" [$$]: Update of data item "${1}" in VPN "${4}" script file failed. | tee -ai "${SYSLOG}" 2> /dev/null
        echo "$(lzdate)" [$$]: Dual WAN VPN support service can\'t be started. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    fi
    echo "$(lzdate)" [$$]: All data items in VPN "${4}" script file have passed the consistency confirmation. | tee -ai "${SYSLOG}" 2> /dev/null
    return 0
}

trans_event_data() {
    cat > "${PATH_TMP}/${VPN_DATA_FILE}" 2> /dev/null <<EOF_EVENT_DATA
${LZ_VERSION}
${WAN_ACCESS_PORT}
${VPN_WAN_PORT}
${POLLING_TIME}
${WAN0}
${WAN1}
${IP_RULE_PRIO_VPN}
${OVPN_SUBNET_IP_SET}
${PPTP_CLIENT_IP_SET}
${IPSEC_SUBNET_IP_SET}
${SYSLOG}
EOF_EVENT_DATA
    [ ! -f "${PATH_TMP}/${VPN_DATA_FILE}" ] && {
        echo "$(lzdate)" [$$]: Failed to transfer data to VPN event data exchange file. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    }
    echo "$(lzdate)" [$$]: Successfully transferred data to VPN event data exchange file. | tee -ai "${SYSLOG}" 2> /dev/null
    return 0
}

trans_daemon_data() {
    cat > "${PATH_TMP}/${VPN_DAEMON_DATA_FILE}" 2> /dev/null <<EOF_DAEMON_DATA
${POLLING_TIME}
${WAN0}
${WAN1}
${VPN_EVENT_INTERFACE_SCRIPTS}
${PPTP_CLIENT_IP_SET}
${IPSEC_SUBNET_IP_SET}
${VPN_DAEMON_IP_SET_LOCK}
EOF_DAEMON_DATA
    [ ! -f "${PATH_TMP}/${VPN_DAEMON_DATA_FILE}" ] && {
        echo "$(lzdate)" [$$]: Failed to transfer data to VPN event data exchange file. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    }
    echo "$(lzdate)" [$$]: Successfully transferred data to VPN daemon data exchange file. | tee -ai "${SYSLOG}" 2> /dev/null
    return 0
}

update_data() {
    local TRANSDATA=
    if [ "${TRANSFER}" = "1" ]; then
        rm -f "${PATH_TMP}/${VPN_DATA_FILE}"
        rm -f "${PATH_TMP}/${VPN_DAEMON_DATA_FILE}"
        TRANSDATA="${LZ_VERSION}>${WAN_ACCESS_PORT}>${VPN_WAN_PORT}>${POLLING_TIME}>${WAN0}>${WAN1}>${IP_RULE_PRIO_VPN}>${OVPN_SUBNET_IP_SET}>${PPTP_CLIENT_IP_SET}>${IPSEC_SUBNET_IP_SET}>${SYSLOG}>"
        if ! consistency_update "TRANSDATA" "${TRANSDATA}" "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" "event processing"; then
            clear_all_event_interface
            return 1
        fi
        TRANSDATA="${POLLING_TIME}>${WAN0}>${WAN1}>${VPN_EVENT_INTERFACE_SCRIPTS}>${PPTP_CLIENT_IP_SET}>${IPSEC_SUBNET_IP_SET}>${VPN_DAEMON_IP_SET_LOCK}>"
        if ! consistency_update "TRANSDATA" "${TRANSDATA}" "${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS}" "daemon"; then
            clear_all_event_interface
            return 1
        fi
    else
        TRANSDATA=">>>>>>>>>>>"
        update_data_item "TRANSDATA" "${TRANSDATA}" "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}"
        update_data_item "TRANSDATA" "${TRANSDATA}" "${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS}"
        ! trans_event_data && {
            clear_all_event_interface
            echo "$(lzdate)" [$$]: Dual WAN VPN support service can\'t be started. | tee -ai "${SYSLOG}" 2> /dev/null
            return 1
        }
        ! trans_daemon_data && {
            clear_all_event_interface
            echo "$(lzdate)" [$$]: Dual WAN VPN support service can\'t be started. | tee -ai "${SYSLOG}" 2> /dev/null
            return 1
        }
    fi
   return 0
}

set_wan_access_port() {
    [ "${WAN_ACCESS_PORT}" != "0" ] && [ "${WAN_ACCESS_PORT}" != "1" ] && return 2
    local router_local_ip="$( ifconfig br0 2> /dev/null | grep "inet addr:" | awk -F ":" '{print $2}' | awk '{print $1}' )" 
    [ -z "${router_local_ip}" ] && {
        echo "$(lzdate)" [$$]: Unable to get local IP of router host. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    }
    local access_wan="${WAN0}"
    [ "${WAN_ACCESS_PORT}" = "1" ] && access_wan="${WAN1}"
    ip rule add from all to "${router_local_ip}" table "${access_wan}" prio "${IP_RULE_PRIO_HOST}" > /dev/null 2>&1
    ip rule add from "${router_local_ip}" table "${access_wan}" prio "${IP_RULE_PRIO_HOST}" > /dev/null 2>&1
    ip route flush cache > /dev/null 2>&1
    if ip rule list prio "${IP_RULE_PRIO_HOST}" | grep -v all | grep -q "${router_local_ip}" \
        && ip rule list prio "${IP_RULE_PRIO_HOST}" | grep all | grep -q "${router_local_ip}"; then
        echo "$(lzdate)" [$$]: WAN access port has been set successfully. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$(lzdate)" [$$]: WAN access port configuration failed. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    fi
    return 0
}

craeate_daemon_start_scripts() {
    cat > "${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}" 2> /dev/null <<EOF_START_DAEMON_SCRIPT
#!/bin/sh
# ${VPN_DAEMON_START_SCRIPT} ${LZ_VERSION}
# By LZ (larsonzhang@gmail.com)
# Do not manually modify!!!

[ ! -d ${PATH_LOCK} ] && { mkdir -p ${PATH_LOCK} > /dev/null 2>&1; chmod 777 ${PATH_LOCK} > /dev/null 2>&1; }
exec $LOCK_FILE_ID<>${LOCK_FILE}; flock -x ${LOCK_FILE_ID} > /dev/null 2>&1;

ipset -q destroy ${VPN_DAEMON_IP_SET_LOCK}
ps | grep ${VPN_DAEMON_SCRIPTS} | grep -v grep | awk '{print \$1}' | xargs kill -9 > /dev/null 2>&1
sleep 1s
nohup /bin/sh ${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS} ${POLLING_TIME} > /dev/null 2>&1 &
ps | grep ${VPN_DAEMON_SCRIPTS} | grep -qv grep && {
    cru d ${START_DAEMON_TIMEER_ID} > /dev/null 2>&1
    sleep 1s
    rm -f ${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}
    lzdate() { eval echo "\$( date +"%F %T" )"; }
    echo "\$(lzdate)" [\$\$]: >> "${SYSLOG}" 2> /dev/null
    echo "\$(lzdate)" [\$\$]: ----------------------------------------------- >> ${SYSLOG} 2> /dev/null
    echo "\$(lzdate)" [\$\$]: The VPN daemon has been started again. >> ${SYSLOG} 2> /dev/null
    echo "\$(lzdate)" [\$\$]: ----------- LZ "${LZ_VERSION}" VPNS Daemon ------------- >> ${SYSLOG} 2> /dev/null
    echo "\$(lzdate)" [\$\$]: >> ${SYSLOG} 2> /dev/null
}

flock -u ${LOCK_FILE_ID} > /dev/null 2>&1

EOF_START_DAEMON_SCRIPT
    chmod +x "${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}" > /dev/null 2>&1
}

start_daemon() {
    ! which nohup > /dev/null 2>&1 && return
    [ "$( nvram get pptpd_enable )" != "1" ] && [ "$( nvram get ipsec_server_enable)" != "1" ] && return

    nohup /bin/sh "${PATH_DAEMON}/${VPN_DAEMON_SCRIPTS}" "${POLLING_TIME}" > /dev/null 2>&1 &
 
    craeate_daemon_start_scripts

    [ -f "${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}" ] \
        && cru a "${START_DAEMON_TIMEER_ID}" "*/1 * * * * /bin/sh ${PATH_TMP}/${VPN_DAEMON_START_SCRIPT}" > /dev/null 2>&1

    if ps | grep "${VPN_DAEMON_SCRIPTS}" | grep -qv grep; then
        echo "$(lzdate)" [$$]: The VPN daemon has been started. | tee -ai "${SYSLOG}" 2> /dev/null
    elif cru l | grep -q "#${START_DAEMON_TIMEER_ID}#"; then
        echo "$(lzdate)" [$$]: The VPN daemon is starting... | tee -ai "${SYSLOG}" 2> /dev/null
    fi
}

create_event_interface() {
    [ ! -d "${PATH_BOOTLOADER}" ] && mkdir -p "${PATH_BOOTLOADER}" > /dev/null 2>&1
    if [ ! -f "${PATH_BOOTLOADER}/${1}" ]; then
        cat > "${PATH_BOOTLOADER}/${1}" 2> /dev/null <<EOF_INTERFACE
#!/bin/sh
EOF_INTERFACE
    fi
    [ ! -f "${PATH_BOOTLOADER}/${1}" ] && return 1
    if ! grep -qm 1 '#!\/bin\/sh' "${PATH_BOOTLOADER}/${1}"; then
        sed -i '1i #!\/bin\/sh' "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
    else
        ! grep -qm 1 '^#!/bin/sh' "${PATH_BOOTLOADER}/${1}" && \
            sed -i 'l1 s:^.*\(#!/bin/sh.*$\):\1/g' "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
    fi
    if ! grep -q "${2}/${3}" "${PATH_BOOTLOADER}/${1}"; then
        sed -i "/${3}/d" "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
        sed -i "\$a ${2}/${3} # Added by LZ" "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
    fi
    chmod +x "${PATH_BOOTLOADER}/${1}" > /dev/null 2>&1
    ! grep -q "${2}/${3}" "${PATH_BOOTLOADER}/${1}" && return 1
    return 0
}

register_event_interface_error() {
    clear_daemon
    clear_time_task
    clear_daemon "1"
    restore_ip_rules
    restore_routing_table
    restore_balance_chain
    clear_ipsets
    delete_data_file
}

register_event_interface() {
    if create_event_interface "${BOOTLOADER_FILE}" "${PATH_LZ}" "${MAIN_SCRIPTS}"; then
        echo "$(lzdate)" [$$]: The script boot start event interface has been successfully registered. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$(lzdate)" [$$]: Script boot start event interface registration failed. | tee -ai "${SYSLOG}" 2> /dev/null
        register_event_interface_error
        echo "$(lzdate)" [$$]: Dual WAN VPN Support service failed to start. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    fi
    if create_event_interface "${VPN_EVENT_FILE}" "${PATH_INTERFACE}" "${VPN_EVENT_INTERFACE_SCRIPTS}"; then
        echo "$(lzdate)" [$$]: Successfully registered VPN event interface. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$(lzdate)" [$$]: VPN event interface registration failed. | tee -ai "${SYSLOG}" 2> /dev/null
        clear_event_interface "$BOOTLOADER_FILE" "${PROJECT_ID}" \
            && echo "$(lzdate)" [$$]: Uninstallation script started boot event interface successfully. | tee -ai "${SYSLOG}" 2> /dev/null
        register_event_interface_error
        echo "$(lzdate)" [$$]: Dual WAN VPN Support service failed to start. | tee -ai "${SYSLOG}" 2> /dev/null
        return 1
    fi
    return 0
}

dual_wan_error() {
    clear_event_interface "$VPN_EVENT_FILE" "${VPN_EVENT_INTERFACE_SCRIPTS}" \
        && echo "$(lzdate)" [$$]: Successfully uninstalled VPN event interface. | tee -ai "${SYSLOG}" 2> /dev/null
    if create_event_interface "${BOOTLOADER_FILE}" "${PATH_LZ}" "${MAIN_SCRIPTS}"; then
        echo "$(lzdate)" [$$]: The script boot start event interface has been successfully registered. | tee -ai "${SYSLOG}" 2> /dev/null
    else
        echo "$(lzdate)" [$$]: Script boot start event interface registration failed. | tee -ai "${SYSLOG}" 2> /dev/null
    fi
    return 0
}

detect_dual_wan() {
    if ! ip route list | grep -q nexthop; then
        echo "$(lzdate)" [$$]: The dual WAN network is not connected. | tee -ai "${SYSLOG}" 2> /dev/null
        dual_wan_error
        return 1
    fi
    echo "$(lzdate)" [$$]: The dual WAN network has been connected. | tee -ai "${SYSLOG}" 2> /dev/null
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
    clear_all_event_interface
    delete_data_file
    echo "$(lzdate)" [$$]: Dual WAN VPN Support service has stopped. | tee -ai "${SYSLOG}" 2> /dev/null
    return 0
}

start_service() {
    update_data || return 1
    detect_dual_wan || return 1
    echo "$(lzdate)" [$$]: Start LZ VPN support service...... | tee -ai "${SYSLOG}" 2> /dev/null
    set_wan_access_port
    /bin/sh "${PATH_INTERFACE}/${VPN_EVENT_INTERFACE_SCRIPTS}" "${PATH_INTERFACE}"
    start_daemon
    register_event_interface || return 1
    echo "$(lzdate)" [$$]: LZ VPN support service started successfully. | tee -ai "${SYSLOG}" 2> /dev/null
    return 0
}


# -------------- Script Execution ---------------

echo "$(lzdate)" [$$]: | tee -ai "${SYSLOG}" 2> /dev/null
echo "$(lzdate)" [$$]: ----------------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null
echo "$(lzdate)" [$$]: LZ "${LZ_VERSION}" vpns script commands start...... | tee -ai "${SYSLOG}" 2> /dev/null
echo "$(lzdate)" [$$]: By LZ \(larsonzhang@gmail.com\) | tee -ai "${SYSLOG}" 2> /dev/null
echo "$(lzdate)" [$$]: ----------------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null

while true
do
    command_parsing || break
    set_lock || break
    init_service || break
    stop_service && break
    start_service
    break
done

unset_lock

echo "$(lzdate)" [$$]: ----------------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null
echo "$(lzdate)" [$$]: LZ "${LZ_VERSION}" vpns script commands executed! | tee -ai "${SYSLOG}" 2> /dev/null
echo "$(lzdate)" [$$]: | tee -ai "${SYSLOG}" 2> /dev/null

exit 0

# END
