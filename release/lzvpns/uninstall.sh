#!/bin/sh
# uninstall.sh v1.0.5
# By LZ (larsonzhang@gmail.com)

# LZ VPNS script for asuswrt/merlin based router

# uninstall script

# BEIGIN

LZ_VERSION=v1.0.5
TIMEOUT=10
CURRENT_PATH="${0%/*}"
[ "${CURRENT_PATH:0:1}" != '/' ] && CURRENT_PATH="$( pwd )${CURRENT_PATH#*.}"
SYSLOG="/tmp/syslog.log"
lzdate() {  date +"%F %T"; }

{
    echo -e "  $(lzdate)\n\n"
    echo "  LZ ${LZ_VERSION} uninstall script starts running..."
    echo "  By LZ (larsonzhang@gmail.com)"
    echo "  $(lzdate)"
    echo
} | tee -ai "${SYSLOG}" 2> /dev/null

! read -r -n1 -t ${TIMEOUT} -p "  Automatically terminate after ${TIMEOUT}s, continue uninstallation? [Y/N] " ANSWER \
    || [ -n "${ANSWER}" ] && echo -e "\r"
case ${ANSWER} in
    Y | y)
    {
        echo | tee -ai "${SYSLOG}" 2> /dev/null
    }
    ;;
    *)
    {
        {
            echo
            echo "  LZ script uninstallation failed."
            echo -e "  $(lzdate)\n\n"
        } | tee -ai "${SYSLOG}" 2> /dev/null
        exit "1"
    }
    ;;
esac

if [ ! -f "${CURRENT_PATH}/lzvpns.sh" ]; then
    {
        echo "$(lzdate)" [$$]: "${CURRENT_PATH}/lzvpns.sh" does not exist.
        echo
        echo "  LZ script uninstallation failed."
        echo -e "  $(lzdate)\n\n"
    } | tee -ai "${SYSLOG}" 2> /dev/null
    exit "1"
else
    chmod +x "${CURRENT_PATH}/lzvpns.sh" > /dev/null 2>&1
    /bin/sh "${CURRENT_PATH}/lzvpns.sh" stop
fi

sleep 1s

{
    echo
    echo "  Uninstallation in progress..."
} | tee -ai "${SYSLOG}" 2> /dev/null

rm -f "${CURRENT_PATH}/daemon/lzvpnsd.sh" > /dev/null 2>&1
rmdir "${CURRENT_PATH}/daemon" > /dev/null 2>&1
rm -f "${CURRENT_PATH}/interface/lzvpnse.sh" > /dev/null 2>&1
rmdir "${CURRENT_PATH}/interface" > /dev/null 2>&1
rmdir "${CURRENT_PATH}/tmp" > /dev/null 2>&1
rm -f "${CURRENT_PATH}/lzvpns.sh" > /dev/null 2>&1
rm -f "${CURRENT_PATH}/uninstall.sh" > /dev/null 2>&1
rm -f "${CURRENT_PATH}/LICENSE" > /dev/null 2>&1
rm -f "${CURRENT_PATH}/README.md" > /dev/null 2>&1
rmdir "${CURRENT_PATH}" > /dev/null 2>&1

{
    echo
    echo "  Software uninstallation completed."
    echo -e "  $(lzdate)\n\n"
} | tee -ai "${SYSLOG}" 2> /dev/null

exit "0"

# END
