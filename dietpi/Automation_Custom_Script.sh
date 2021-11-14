# !/bin/bash
#######################################################################
# Name:     DietPiOS64-FA-Install.sh           Version:      0.1.2    #
# Created:  13.11.2021                      Modified: 14.11.2021      #
# Author:   TuxfeatMac J.T.                                           #
# Purpose:  interactive, automatic, Pimox7 installation RPi4B, RPi3B+ #
#######################################################################
# Tested with image from:					      #
# https://dietpi.com/downloads/images/DietPi_RPi-ARMv8-Bullseye.7z    #
#######################################################################################################
#-----------------------------------------------------------------------------------------------------#
#---- CONFIGURE-OPTIONS ------------------------------------------------------------------------------#
#-----------------------------------------------------------------------------------------------------#
CONFIG_ZRAM='yes/no'	# (default) no	  | install zram for swap ?	|			      #
       ZRAM='1664'	# (default) 1,6GB |				| 			      #
CONFIG_SWAP='yes/no'	# (default) no    | install dphys-swapfile ?	|			      #
       SWAP='384'	# (default) 0,4GB | 				| combined 2,0GB swap	      #
GET_STD_CTS='yes/no'	# (default) no 	  | Debian & Ubuntu ARM64 TEMPLATEs	| ! DLSIZE ~ 0,15GB   #
GET_STD_ISO='yes/no'	# (default) no	  | Debian & Ubuntu ARM64 Install ISOs	| ! DLSIZE ~ 1,35GB   #
CONF_BANNER='yes'	# (default) yes	  | Replaces the No Subscrition banner with a pimox banner    #
#-----------------------------------------------------------------------------------------------------#
#---- END-CONFIGURE-OPTIONS - ! NO TOUCHI BELOW THIS LINE ! - UNLESS YOU KNOW WHAT YOU ARE DOING -----#
#-----------------------------------------------------------------------------------------------------#
#######################################################################################################

#### GET IP HOSTNAME NETAMSK AND GATEWAY FROM dietpi.txt ################################################################################
  RPI_IP=$(cat /boot/dietpi.txt | grep AUTO_SETUP_NET_STATIC_IP | cut -d '=' -f 2)
 NETMASK=$(cat /boot/dietpi.txt | grep AUTO_SETUP_NET_STATIC_MASK | cut -d '=' -f 2)
 GATEWAY=$(cat /boot/dietpi.txt | grep AUTO_SETUP_NET_STATIC_GATEWAY | cut -d '=' -f 2)
HOSTNAME=$(cat /boot/dietpi.txt | grep AUTO_SETUP_NET_HOSTNAME | cut -d '=' -f 2)  

#### SET SOME COLOURS ###################################################################################################################
NORMAL=$(tput sgr0)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
GREY=$(tput setaf 8)

#### BASE UPDATE, DEPENDENCIES INSTALLATION #############################################################################################
printf "
=========================================================================================
 $GREEN Begin installation, Normal duration on a default RPi3+ ~ $YELLOW 30 $GREEN minutes, be patient...! $NORMAL
=========================================================================================\n
"
apt update && apt upgrade -y # Allready done by DietPi, check anyway...
#apt install nmon htop atop # tools you need...

#### ZRAM SWAP INSTALL ##################################################################################################################
if [ "$CONFIG_ZRAM" == "yes" ]
 then
  apt install -y zram-tools
  printf "SIZE=$ZRAM\nPRIORITY=100\nALGO=lz4\n" >> /etc/default/zramswap
  printf "vm.swappiness=90\n" >> /etc/sysctl.d/99-sysctl.conf
  systemctl restart zramswap.service
  sysctl vm.swappiness=90
fi

#### DPHYS-SWAPFILE SWAP INSTALL ########################################################################################################
if [ "$CONFIG_SWAP" == "yes" ]
 then
  apt install -y dphys-swapfile
  printf "CONF_SWAPSIZE=$SWAP\n" >> /etc/dphys-swapfile
  systemctl restart dphys-swapfile.service
fi

#### FIX CONTAINER STATS NOT SHOWING UP IN WEB GUI #######################################################################################
if [ "$(cat /boot/cmdline.txt | grep cgroup)" != "" ]
 then
  printf "Seems to be already fixed!"
 else
  sed -i "1 s|$| cgroup_enable=cpuset cgroup_enable=memory cgroup_memory=1|" /boot/cmdline.txt
fi

#### PRE FETCH ISOS / CT TEMPLATES #######################################################################################################
if [ "$GET_STD_CTS" == "yes" ]
 then
  mkdir -p /var/lib/vz
  mkdir -p /var/lib/vz/template
  mkdir -p /var/lib/vz/template/cache
  cd /var/lib/vz/template/cache
  BASEURL='https://uk.lxd.images.canonical.com/images'
  ARCHITEC='arm64'
  ### Debian 11 Arm 64 - CT ROOTFS ###
  DISTNAME=debian
  CODENAME=bullseye
  NEWESTBUILD=$(curl -s $BASEURL/$DISTNAME/$CODENAME/$ARCHITEC/default/ | grep '<td>' | tail -n 1 | cut -d '='  -f 5 | cut -d '/' -f 2)
  wget -q $BASEURL/$DISTNAME/$CODENAME/$ARCHITEC/default/$NEWESTBUILD/rootfs.tar.xz -O Debian11$ARCHITEC-std-$NEWESTBUILD.tar.xz
  ### Ubuntu 20.04 LTS Arm 64 - CT ROOTFS ###
  DISTNAME=ubuntu
  CODENAME=focal
  NEWESTBUILD=$(curl $BASEURL/$DISTNAME/$CODENAME/$ARCHITEC/default/ | grep '<td>' | tail -n 1 | cut -d '='  -f 5 | cut -d '/' -f 2)
  wget -q $BASEURL/$DISTNAME/$CODENAME/$ARCHITEC/default/$NEWESTBUILD/rootfs.tar.xz -O Ubuntu20$ARCHITEC-std-$NEWESTBUILD.tar.xz
fi
if [ "$GET_STD_ISO" == "yes" ]
 then
  mkdir -p /var/lib/vz
  mkdir -p /var/lib/vz/template
  mkdir -p /var/lib/vz/template/iso
  cd /var/lib/vz/template/iso
  wget -q https://cdimage.debian.org/debian-cd/current/arm64/iso-cd/debian-11.1.0-arm64-netinst.iso	# debian arm64 net installer iso
  wget -q https://cdimage.ubuntu.com/releases/20.04/release/ubuntu-20.04.3-live-server-arm64.iso   	# ubuntu arm64 server iso
fi

#### ADD SOURCE PIMOX7 + KEY & UPDATE & INSTALL RPI-KERNEL-HEADERS & ZFS-DKMS ############################################################
printf "# PiMox7 Development Repo
deb https://raw.githubusercontent.com/pimox/pimox7/master/ dev/ \n" > /etc/apt/sources.list.d/pimox.list
curl -s https://raw.githubusercontent.com/pimox/pimox7/master/KEY.gpg | apt-key add -
apt update && apt install -y raspberrypi-kernel-headers 
DEBIAN_FRONTEND=noninteractive apt install -y -o Dpkg::Options::="--force-confdef" zfs-dkms

#### CONFIGURE NETWORK FOR PIMOX7 SETUP ##################################################################################################
printf "127.0.0.1\tlocalhost
$RPI_IP_ONLY\t$HOSTNAME\n" > /etc/hosts
printf "auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
        address $RPI_IP
        netmask $NETMASK
        gateway $GATEWAY\n" > /etc/network/interfaces
hostnamectl set-hostname $HOSTNAME

#### INSTALL PIMOX7 ######################################################################################################################
DEBIAN_FRONTEND=noninteractive apt install -y -o Dpkg::Options::="--force-confdef" proxmox-ve

#### CONFIGURE PIMOX7 BANNER #############################################################################################################
if [ "$CONF_BANNER" == "yes" ]
 then
  sudo cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.auto.backup
  SEARCH="return Ext.String.format('"
  #### PLACE HOLDER RULER ## BANNER BEGINN ## #### LINE 1 ####                                                     #### LINEBREAK #### -- #### LINE 2 #####
  REPLACE="return Ext.String.format(' This is a unofficial development build of PVE7 - PIMOX7 - https://github.com/pimox/pimox7  Build to run a PVE7 on the RPi4. ! ! ! NO GUARANTEE NOT OFFICCIAL SUPPORTED ! ! ! ');"
  sed -i "s|$SEARCH.*|$REPLACE|" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
fi

#### RECONFIGURE NETWORK #### /etc/hosts REMOVE IPv6 #### /etc/network/interfaces.new CONFIGURE NETWORK TO CHANGE ON REBOOT ##############
printf "
=========================================================================================
$GREEN ! FIXING NETWORK CONFIGURATION.... ERRORS ARE NOMALAY FINE AND RESOLVED AFTER REBOOT ! $NORMAL
=========================================================================================
\n"
printf "127.0.0.1\tlocalhost
$RPI_IP_ONLY\t$HOSTNAME\n" > /etc/hosts
printf "auto lo
iface lo inet loopback

iface eth0 inet manual

auto vmbr0
iface vmbr0 inet static
        address $RPI_IP
        netmask $NETMASK
        gateway $GATEWAY

        bridge-ports eth0
        bridge-stp off
        bridge-fd 0 \n" > /etc/network/interfaces.new
hostnamectl set-hostname $HOSTNAME

### FINAL MESSAGE & REBOOT ###############################################################################################################
printf "
=========================================================================================
                   $GREEN     ! INSTALATION COMPLETED ! WAIT ! REBOOT ! $NORMAL
=========================================================================================

    after rebbot the PVE web interface will be reachable here :
      --->  $GREEN https://$RPI_IP_ONLY:8006/ $NORMAL <---

\n" && sleep 15 && reboot

#### EOF ####
