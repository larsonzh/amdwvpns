#!/bin/sh
# uninstall.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# LZ script for asuswrt/merlin based router


# uninstall script

# BEIGIN

LZ_VERSION=v0.0.1
CURRENT_PATH="${0%/*}"
[ "${CURRENT_PATH:0:1}" != '/' ] && CURRENT_PATH="$( pwd )${CURRENT_PATH#*.}"
SYSLOG="/tmp/syslog.log"
lzdate() { eval echo "$( date +"%F %T" )"; }

echo  | tee -ai "${SYSLOG}" 2> /dev/null
echo ----------------------------------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null
echo "  LZ ${LZ_VERSION} uninstall script starts running..." | tee -ai "${SYSLOG}" 2> /dev/null
echo "  By LZ (larsonzhang@gmail.com)" | tee -ai "${SYSLOG}" 2> /dev/null
echo "  $(lzdate)" | tee -ai "${SYSLOG}" 2> /dev/null
echo ----------------------------------------------------------------- | tee -ai "${SYSLOG}" 2> /dev/null

if [ ! -f "${CURRENT_PATH}/lzvpns.sh" ]; then
    echo "$(lzdate)" [$$]: "${CURRENT_PATH}/lzvpns.sh" does not exist. | tee -ai "${SYSLOG}" 2> /dev/null
    exit 1
else
    chmod +x "${CURRENT_PATH}/lzvpns.sh" > /dev/null 2>&1
    sh "${CURRENT_PATH}/lzvpns.sh" stop
fi

exit 0

# END
