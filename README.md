# amdwvpns
Asus-Merlin Dual WAN VPN Support tool

**v1.0.3**

This project is used to solve the problem that the client can't access and use the VPN server inside the router when the dual WAN port of ASUS Merlin router is connected to the external network.

The router VPN servers involved in this project include OpenVPN server, PPTP VPN server and IPSec VPN server.

The project script can be deployed and run in the JFFS partition of the router or the Entware environment in the USB disk.

Since the author's amdwprsct project has included all the functions of this project, in order to avoid the application running conflict, the project script can't run in the router at the same time as the author's amdwprsct project product.

For the author's amdwprsct project, please visit the following address: https://github.com/larsonzh/amdwprprsct.git


**Installation & Operation**

1. Download the compressed package named "lzvpns-[version ID].tgz" (e.g., lzvpns-v1.0.2.tgz).

2. Upload the compressed package to the temporary directory in the router.

3. In the SSH terminal, use the tar command to extract files in the temporary directory:
```markdown
        tar -xzvf lzvpns-[version ID].tgz
```
4. After executing the above command, execute the installation script command in the newly created directory (lzvpns-[version ID]):
```markdown
        To JFFS partition            ./install.sh
            or
        To the Entware of USB disk   ./install.sh entware
```
5. After installation, the following commands can be executed in the lzvpns directory where the script file is located:
```markdown
        Start/Restart Service        ./lzvpns.sh
        Stop Service                 ./lzvpns.sh stop
        Forced Unlocking             ./lzvpns.sh unlock
        Uninstall project files      ./uninstall.sh
```
6. In the user-defined data area of the script file (lzvpns.sh), you can configure three basic operation parameters according to the instructions.

```markdown
#  ------------- User Defined Data --------------

# The host port of the router, which is used by the VPN client when accessing the router 
# from the WAN using the domain name or IP address. 
# 0--Primary WAN (Default), 1--Secondary WAN
WAN_ACCESS_PORT=0

# The router host port used by VPN clients when accessing the WAN through the router.
# 0--Primary WAN (Default), 1--Secondary WAN, Other--System Allocation
VPN_WAN_PORT=0

# Polling time for detecting and maintaining PPTP/IPSec VPN service status.
# 1~10s (The default is 3 seconds)
POLLING_TIME=3

```
