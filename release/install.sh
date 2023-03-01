#!/bin/sh
# install.sh v1.0.5
# By LZ (larsonzhang@gmail.com)

# LZ VPNS script for asuswrt/merlin based router

# Script command (e.g., in the parent directory of lzvpns directory)
# JFFS partition            ./install.sh
# the Entware of USB disk   ./install.sh entware

# install script

# BEIGIN

LZ_VERSION=v1.0.5
TIMEOUT=10
CURRENT_PATH="${0%/*}"
[ "${CURRENT_PATH:0:1}" != '/' ] && CURRENT_PATH="$( pwd )${CURRENT_PATH#*.}"
SYSLOG="/tmp/syslog.log"
PATH_BASE="/jffs/scripts"
lzdate() { date +"%F %T"; }

{
    echo -e "\n\n"
    echo "  LZ ${LZ_VERSION} installation script starts running..."
    echo "  By LZ (larsonzhang@gmail.com)"
    echo "  $(lzdate)"
    echo
} | tee -ai "${SYSLOG}" 2> /dev/null

if [ -z "${USER}" ]; then
    {
        echo "  "The user name is empty and can\'t continue.
        echo
        echo "  LZ script installation failed."
        echo -e "  $(lzdate)\n\n"
    } | tee -ai "${SYSLOG}" 2> /dev/null
    exit "1"
elif [ "${USER}" = "root" ]; then
    {
        echo "  "The root user can\'t install this software.
        echo "  Please log in with a different name."
        echo
        echo "  LZ script installation failed."
        echo -e "  $(lzdate)\n\n"
    } | tee -ai "${SYSLOG}" 2> /dev/null
    exit "1"
fi

AVAL_SPACE=
if [ "${1}" = "entware" ]; then
    if which opkg > /dev/null 2>&1; then
        for sditem in $( df | awk '$1 ~ /^\/dev\/sd/ {print $1":-"$4":-"$6}' )
        do
            if  ls "${sditem##*:-}/entware" > /dev/null 2>&1; then
                AVAL_SPACE="${sditem#*:-}"; AVAL_SPACE="${AVAL_SPACE%:-*}";
                if which opkg 2> /dev/null | grep -qw '^[\/]opt' && [ -d "/opt/home" ]; then
                    PATH_BASE="/opt/home"
                else
                    PATH_BASE="${sditem##*:-}/entware/home"
                fi
                break
            fi
        done
    fi
    if [ -z "${AVAL_SPACE}" ]; then
        {
            echo "  "Entware can\'t be used or doesn\'t exist.
            echo
            echo "  LZ script installation failed."
            echo -e "  $(lzdate)\n\n"
        } | tee -ai "${SYSLOG}" 2> /dev/null
        exit "1"
    fi
else
    AVAL_SPACE="$( df | grep -w "/jffs" | awk '{print $4}' )"
fi

SPACE_REQU="$( du -s "${CURRENT_PATH}" | awk '{print $1}' )"

[ -n "${AVAL_SPACE}" ] && AVAL_SPACE="${AVAL_SPACE} KB" || AVAL_SPACE="Unknown"
[ -n "${SPACE_REQU}" ] && SPACE_REQU="${SPACE_REQU} KB" || SPACE_REQU="Unknown"

{
    echo -e "  Available space: ${AVAL_SPACE}\tSpace required: ${SPACE_REQU}"
    echo
} | tee -ai "${SYSLOG}" 2> /dev/null

if [ "${AVAL_SPACE}" != "Unknown" ] && [ "${SPACE_REQU}" != "Unknown" ]; then
    if [ "${AVAL_SPACE% KB*}" -le "${SPACE_REQU% KB*}" ]; then
        {
            echo "  Insufficient free space to install."
            echo
            echo "  LZ script installation failed."
            echo -e "  $(lzdate)\n\n"
        } | tee -ai "${SYSLOG}" 2> /dev/null
        exit "1"
    fi
elif [ "${AVAL_SPACE}" = "Unknown" ] || [ "${SPACE_REQU}" = "Unknown" ]; then
    echo "  Available space is uncertain."
    ! read -r -n1 -t "${TIMEOUT}" -p "  Automatically terminate after ${TIMEOUT}s, continue installation? [Y/N] " ANSWER \
        || [ -n "${ANSWER}" ] && echo -e "\r"
    case ${ANSWER} in
        Y | y)
        {
            echo | tee -ai "${SYSLOG}" 2> /dev/null
        }
        ;;
        N | n)
        {
            {
                echo
                echo "  The installation was terminated by the current user."
                echo -e "  $(lzdate)\n\n"
            } | tee -ai "${SYSLOG}" 2> /dev/null
            exit "1"
        }
        ;;
        *)
        {
            {
                echo
                echo "  LZ script installation failed."
                echo -e "  $(lzdate)\n\n"
            } | tee -ai "${SYSLOG}" 2> /dev/null
            exit "1"
        }
        ;;
    esac
fi

echo "  Installation in progress..." | tee -ai "${SYSLOG}" 2> /dev/null

PATH_LZ="${PATH_BASE}/lzvpns"
if ! mkdir -p "${PATH_LZ}" > /dev/null 2>&1; then
    {
        echo | tee -ai "${SYSLOG}" 2> /dev/null
        echo "  Failed to create directory (${PATH_LZ})."
        echo "  The installation process exited."
        echo
        echo "  LZ script installation failed."
        echo -e "  $(lzdate)\n\n"
    } | tee -ai "${SYSLOG}" 2> /dev/null
    exit "1"
fi

if ! cp -rpf "${CURRENT_PATH}/lzvpns" "${PATH_BASE}" > /dev/null 2>&1; then
    rm -f "${PATH_LZ}/daemon/lzvpnsd.sh" > /dev/null 2>&1
    rmdir "${PATH_LZ}/daemon" > /dev/null 2>&1
    rm -f "${PATH_LZ}/interface/lzvpnse.sh" > /dev/null 2>&1
    rmdir "${PATH_LZ}/interface" > /dev/null 2>&1
    rm -f "${PATH_LZ}/lzvpns.sh" > /dev/null 2>&1
    rm -f "${PATH_LZ}/uninstall.sh" > /dev/null 2>&1
    rmdir "${PATH_LZ}" > /dev/null 2>&1

    {
        echo
        echo "  Software installation failed."
        echo -e "  $(lzdate)\n\n"
    } | tee -ai "${SYSLOG}" 2> /dev/null
    exit "1"
else
    cp -rpf "${CURRENT_PATH}/LICENSE" "${PATH_LZ}" > /dev/null 2>&1
    cp -rpf "${CURRENT_PATH}/README.md" "${PATH_LZ}" > /dev/null 2>&1
fi

chmod 775 "${PATH_LZ}/lzvpns.sh" > /dev/null 2>&1
chmod -R 775 "${PATH_LZ}" > /dev/null 2>&1

{
    echo
    echo "  Installed script path: ${PATH_BASE}"
    echo "  The software installation has been completed."
    echo
    echo "               LZ VPNS Script Command"
    echo
    echo "  Start/Restart Service   ${PATH_LZ}/lzvpns.sh"
    echo "  Stop Service            ${PATH_LZ}/lzvpns.sh stop"
    echo "  Forced Unlocking        ${PATH_LZ}/lzvpns.sh unlock"
    echo "  Uninstall               ${PATH_LZ}/uninstall.sh"
    echo
    echo -e "  $(lzdate)\n\n"
} | tee -ai "${SYSLOG}" 2> /dev/null

exit "0"

# END
