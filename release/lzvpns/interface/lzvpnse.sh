#!/bin/sh
# lzvpnse.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# VPN event processing script

# BEIGIN

# -------- lzvpns.sh transfer data area ---------
# ---------- Don't manually modify !!! ----------
VPN_WAN_PORT=0
# ---------- Don't manually modify !!! ----------
# -----------------------------------------------

WAN0=100
WAN1=200
IP_RULE_PRIO_VPN=998
OVPN_SUBNET_IP_SET="lzvpns_ovpn_subnet"
PPTP_CLIENT_IP_SET="lzvpns_pptp_client"
IPSEC_SUBNET_IP_SET="lzvpns_ipsec_subnet"
SYSLOG_FILE="/tmp/syslog.log"

# END
