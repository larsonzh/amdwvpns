#!/bin/sh
# install.sh v0.0.1
# By LZ (larsonzhang@gmail.com)

# LZ VPNS script for asuswrt/merlin based router

# Script command (e.g., in the parent directory of lzvpns directory)
# JFFS partition            ./install.sh
# the Entware of USB disk   ./install.sh entware


# install script

# BEIGIN

LZ_VERSION=v0.0.1
TIMEOUT=10
CURRENT_PATH="${0%/*}"
[ "${CURRENT_PATH:0:1}" != '/' ] && CURRENT_PATH="$( pwd )${CURRENT_PATH#*.}"
SYSLOG="/tmp/syslog.log"
PATH_BASE=/jffs/scripts
lzdate() { eval echo "$( date +"%F %T" )"; }

echo -e "\n\n" | tee -ai "${SYSLOG}" 2> /dev/null
echo "  LZ ${LZ_VERSION} installation script starts running..." | tee -ai "${SYSLOG}" 2> /dev/null
echo "  By LZ (larsonzhang@gmail.com)" | tee -ai "${SYSLOG}" 2> /dev/null
echo "  $(lzdate)" | tee -ai "${SYSLOG}" 2> /dev/null
echo | tee -ai "${SYSLOG}" 2> /dev/null

if [ -z "${USER}" ]; then
    echo "  The user name is empty and can\'t continue." | tee -ai "${SYSLOG}" 2> /dev/null
    echo | tee -ai "${SYSLOG}" 2> /dev/null
    echo "  LZ script installation failed." | tee -ai "${SYSLOG}" 2> /dev/null
    echo -e "  $(lzdate)\n\n" | tee -ai "${SYSLOG}" 2> /dev/null
    exit 1
elif [ "${USER}" = root ]; then
    echo "  The root user can\'t install this software." | tee -ai "${SYSLOG}" 2> /dev/null
    echo "  Please log in with a different name." | tee -ai "${SYSLOG}" 2> /dev/null
    echo | tee -ai "${SYSLOG}" 2> /dev/null
    echo "  LZ script installation failed." | tee -ai "${SYSLOG}" 2> /dev/null
    echo -e "  $(lzdate)\n\n" | tee -ai "${SYSLOG}" 2> /dev/null
    exit 1
fi

AVAL_SPACE=
if [ "${1}" = "entware" ]; then
    if which opkg > /dev/null 2>&1; then
        index=1
        while [ "${index}" -le "$( df | grep -c "^/dev/sda" )" ]
        do
            if df | grep -w "^/dev/sda${index}" | awk '{print $6}' | xargs -I {} ls -al {} | grep -qo "entware"; then
                AVAL_SPACE=$( df | grep -w "^/dev/sda${index}" | awk '{print $4}' )
                if which opkg 2> /dev/null | grep -qwo '^[\/]opt' && [ -d "/opt/home" ]; then
                    PATH_BASE="/opt/home"
                else
                    PATH_BASE="$( df | grep -w "^/dev/sda${index}" | awk '{print $6}' )/entware/home"
                fi
                break
            fi
            let index++
        done
    fi
    if [ -z "${AVAL_SPACE}" ]; then
        echo "  Entware can\'t be used or doesn\'t exist." | tee -ai "${SYSLOG}" 2> /dev/null
        echo | tee -ai "${SYSLOG}" 2> /dev/null
        echo "  LZ script installation failed." | tee -ai "${SYSLOG}" 2> /dev/null
        echo -e "  $(lzdate)\n\n" | tee -ai "${SYSLOG}" 2> /dev/null
        exit 1
    fi
else
    AVAL_SPACE=$( df | grep -w "/jffs" | awk '{print $4}' )
fi

SPACE_REQU=$( du -s "${CURRENT_PATH}" | awk '{print $1}' )

[ -n "${AVAL_SPACE}" ] && AVAL_SPACE="${AVAL_SPACE} KB" || AVAL_SPACE="Unknown"
[ -n "${SPACE_REQU}" ] && SPACE_REQU="${SPACE_REQU} KB" || SPACE_REQU="Unknown"

echo -e "  Available space: ${AVAL_SPACE}\tSpace required: ${SPACE_REQU}" | tee -ai "${SYSLOG}" 2> /dev/null
echo | tee -ai "${SYSLOG}" 2> /dev/null

if [ "${AVAL_SPACE}" != "Unknown" ] && [ "${SPACE_REQU}" != "Unknown" ]; then
    if [ "${AVAL_SPACE% KB*}" -le "${SPACE_REQU% KB*}" ]; then
        echo "  Insufficient free space to install." | tee -ai "${SYSLOG}" 2> /dev/null
        echo | tee -ai "${SYSLOG}" 2> /dev/null
        echo "  LZ script installation failed." | tee -ai "${SYSLOG}" 2> /dev/null
        echo -e "  $(lzdate)\n\n" | tee -ai "${SYSLOG}" 2> /dev/null
        exit 1
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
            echo | tee -ai "${SYSLOG}" 2> /dev/null
            echo "  The installation was terminated by the current user." | tee -ai "${SYSLOG}" 2> /dev/null
            echo -e "  $(lzdate)\n\n" | tee -ai "${SYSLOG}" 2> /dev/null
            exit 1
        }
        ;;
        *)
        {
            echo | tee -ai "${SYSLOG}" 2> /dev/null
            echo "  LZ script installation failed." | tee -ai "${SYSLOG}" 2> /dev/null
            echo -e "  $(lzdate)\n\n" | tee -ai "${SYSLOG}" 2> /dev/null
            exit 1
        }
        ;;
    esac
fi

echo "  Installation in progress..." | tee -ai "${SYSLOG}" 2> /dev/null

PATH_LZ="${PATH_BASE}/lzvpns"
if ! mkdir -p "${PATH_LZ}" > /dev/null 2>&1; then
    echo | tee -ai "${SYSLOG}" 2> /dev/null
    echo "  Failed to create directory (${PATH_LZ})." | tee -ai "${SYSLOG}" 2> /dev/null
    echo "  The installation process exited." | tee -ai "${SYSLOG}" 2> /dev/null
    echo | tee -ai "${SYSLOG}" 2> /dev/null
    echo "  LZ script installation failed." | tee -ai "${SYSLOG}" 2> /dev/null
    echo -e "  $(lzdate)\n\n" | tee -ai "${SYSLOG}" 2> /dev/null
    exit 1
fi

if ! cp -rpf "${CURRENT_PATH}/lzvpns" "${PATH_BASE}" > /dev/null 2>&1; then
    rm -f "${PATH_LZ}/daemon/lzvpnsd.sh"
    rmdir "${PATH_LZ}/daemon" > /dev/null 2>&1
    rm -f "${PATH_LZ}/interface/lzvpnse.sh"
    rmdir "${PATH_LZ}/interface" > /dev/null 2>&1
    rm -f "${PATH_LZ}/lzvpns.sh"
    rm -f "${PATH_LZ}/uninstall.sh"
    rmdir "${PATH_LZ}" > /dev/null 2>&1

    echo | tee -ai "${SYSLOG}" 2> /dev/null
    echo "  Software installation failed." | tee -ai "${SYSLOG}" 2> /dev/null
    echo -e "  $(lzdate)\n\n" | tee -ai "${SYSLOG}" 2> /dev/null
    exit 1
else
    cp -rpf "${CURRENT_PATH}/LICENSE" "${PATH_LZ}" > /dev/null 2>&1
    cp -rpf "${CURRENT_PATH}/README.md" "${PATH_LZ}" > /dev/null 2>&1
fi

chmod 775 "${PATH_LZ}/lzvpns.sh" > /dev/null 2>&1
chmod -R 775 "${PATH_LZ}" > /dev/null 2>&1

echo | tee -ai "${SYSLOG}" 2> /dev/null
echo "  Installed script path: ${PATH_BASE}" | tee -ai "${SYSLOG}" 2> /dev/null
echo "  The software installation has been completed." | tee -ai "${SYSLOG}" 2> /dev/null
echo | tee -ai "${SYSLOG}" 2> /dev/null
echo "               LZ VPNS Script Command" | tee -ai "${SYSLOG}" 2> /dev/null
echo | tee -ai "${SYSLOG}" 2> /dev/null
echo "  Start/Restart Service   ${PATH_LZ}/lzvpns.sh" | tee -ai "${SYSLOG}" 2> /dev/null
echo "  Stop Service            ${PATH_LZ}/lzvpns.sh stop" | tee -ai "${SYSLOG}" 2> /dev/null
echo "  Forced Unlocking        ${PATH_LZ}/lzvpns.sh unlock" | tee -ai "${SYSLOG}" 2> /dev/null
echo "  Uninstall               ${PATH_LZ}/uninstall.sh" | tee -ai "${SYSLOG}" 2> /dev/null
echo | tee -ai "${SYSLOG}" 2> /dev/null
echo -e "  $(lzdate)\n\n" | tee -ai "${SYSLOG}" 2> /dev/null

exit 0

# END
