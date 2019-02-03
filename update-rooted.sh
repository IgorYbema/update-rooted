#!/bin/sh

echo "==================================================================================================================================================================="
echo "Welcome to the rooted Toon upgrade script. This script will try to upgrade your Toon using your original connection with Eneco. It will start the VPN if necessary."
echo "Please be advised that running this script is at your own risk!"
echo ""
echo "Version: 3.55  - TheHogNL & TerrorSource & yjb - 3-2-2019"
echo ""
echo "If you like the update script for rooted toons you can support me. Any donation is welcome and helps me developing the script even more."
echo "https://paypal.me/pools/c/8bU3eQp1Jt"
echo ""
echo "==================================================================================================================================================================="
echo ""

# YJB 19102018 usage function
usage() {
	echo ""
	echo `basename $0`" [OPTION]

	This script will try to upgrade your Toon using your original
	connection with Eneco.
	!!Running this script is at your own risk!!

	Options:
	-v <version> Upgrade to a specific version
	-a Activation only
	-b Installation of Busybox, OWN RISK !
	-d Skip starting VPN
	-s <url> provide custom repo url
	-f Only fix files without a version update
	-u unattended mode (always answer with yes) 
	-h Display this help text
	"
}


autoUpdate() {
	MD5ME=`/usr/bin/md5sum $0 | cut -d\  -f1`
	MD5ONLINE=`curl --compressed -Nks https://raw.githubusercontent.com/IgorYbema/update-rooted/master/update-rooted.md5 | cut -d\  -f1`
	if [ !  "$MD5ME" == "$MD5ONLINE" ]
	then
		echo "Warning: there is a new version of update-rooted.sh available! Do you want me to download it for you (yes/no)?" 
		if ! $UNATTENDED ; then read QUESTION ; fi	
		if [  "$QUESTION" == "yes" ] &&  ! $UNATTENDED #no auto update in unattended mode
		then
			curl --compressed -Nks https://raw.githubusercontent.com/IgorYbema/update-rooted/master/update-rooted.sh -o $0
			echo "Ok I downloaded the update. Restarting..." 
			/bin/sh $0 $@
			exit
		fi
	fi
}


fixGlobalsFile() {
	#determine where this Toon is storing the apps
	APPDIR='/qmf/qml/apps'
	if [ ! -d "$APPDIR" ]
	then
		APPDIR='/HCBv2/qml/apps/'
	fi

	#determine where this Toon is storing the base dir
	BASEDIR='/qmf/qml/qb/base'
	if [ ! -d "$APPDIR" ]
	then
		BASEDIR='/HCBv2/qml/qb/base'
	fi

	for app in `find $APPDIR -maxdepth 1 -type l | sed 's/.*apps\///'`
	do
		if ! ( grep -q $app $BASEDIR/Globals.qml )
		then
			echo "Restoring $app in Globals.qml"
			sed -i '/"clock",/a\                                                "'$app'",' $BASEDIR/Globals.qml
		fi
	done
}

fixInternetSettingsApp() {
	settingsfile="/HCBv2/qml/apps/internetSettings/InternetSettingsApp.qml"
	if ! grep -q "if ( smStatus == _ST_INTERNET ) { smStatus = _ST_TUNNEL;" $settingsfile
	then
		echo "Modification in InternetSettingsApp.qml is missing. Fixing it now."
		sed -i '/smStatus = parseInt(statemachine)/a\  if ( smStatus == _ST_INTERNET ) { smStatus = _ST_TUNNEL; }' $settingsfile
	fi
}

editVPNconnection(){
	#disableVPN for rooted toons
	#enables ovpn if it is already disabled
	sed -i 's~#ovpn:235~ovpn:235~g' /etc/inittab
	#disables ovpn if it's enabled
	sed -i 's~ovpn:235~#ovpn:235~g' /etc/inittab
}

editSerialConnection(){
	# Adds serial connection
	# remove existing serial connection if needed
	sed -i '/# add serial/d' /etc/inittab
	sed -i '/gett:235:respawn/d' /etc/inittab
	# adding new serial connection:
	sed -i '/qtqt:245/a\# add serial console access:\ngett:235:respawn:/sbin/getty -L 115200 ttymxc0 vt102' /etc/inittab
}

editTimeServer() {
	#edit time server
	sed -i '/#server time.quby.nl minpoll 8/d' /etc/chrony.conf
	sed -i 's~server time.quby.nl minpoll 8~#server time.quby.nl minpoll 8\nserver 0.nl.pool.ntp.org minpoll 8\nserver 1.nl.pool.ntp.org minpoll 8\nserver 2.nl.pool.ntp.org minpoll 8\nserver 3.nl.pool.ntp.org minpoll 8~g' /etc/chrony.conf
	sed -i '/#initstepslew .* time.quby.nl/d' /etc/chrony.conf
	sed -i 's~initstepslew .* time.quby.nl~#initstepslew 30 time.quby.nl\ninitstepslew 30 0.nl.pool.ntp.org\ninitstepslew 30 1.nl.pool.ntp.org\ninitstepslew 30 2.nl.pool.ntp.org\ninitstepslew 30 3.nl.pool.ntp.org~g' /etc/chrony.conf
	#removing stupid local binding of chrony
	sed -i '/bindaddress/d' /etc/chrony.conf
	sed -i '/bindcmdaddress/d' /etc/chrony.conf
}

editHostfile(){
	#edit hosts file
	#remove current comment lines + resolve ping.quby.nl to localhost
	sed -i '/ping.quby.nl/d' /etc/hosts
	echo '127.0.0.1    ping.quby.nl' >> /etc/hosts
}

editQMFConfigFile(){
	#removing data gathering by quby
	sed -i '/test.datalab.toon.eu/d' /HCBv2/etc/qmf_tenant.xml
	sed -i '/eneco.bd.toon.eu/d' /HCBv2/etc/qmf_tenant.xml
	sed -i '/quby.count.ly/d' /HCBv2/etc/qmf_tenant.xml
	#whitelisting web service
	sed -i 's/<enforceWhitelist>1/<enforceWhitelist>0/' /HCBv2/etc/qmf_release.xml
}

editWifiPM(){
	#creating file to disable wifi powermanagment after reboot
	echo "/sbin/wl PM 0" > /etc/udhcpc.d/90tsc	
	chmod +x /etc/udhcpc.d/90tsc
}

editActivation() {
	#editing config_happ_scsync.xml for activation
	sed -i 's~Standalone~Toon~g' /qmf/config/config_happ_scsync.xml
	sed -i 's~<activated>0</activated>~<activated>1</activated>~g' /qmf/config/config_happ_scsync.xml
	sed -i 's~<wizardDone>0</wizardDone>~<wizardDone>1</wizardDone>~g' /qmf/config/config_happ_scsync.xml
	sed -i 's~<SoftwareUpdates>0</SoftwareUpdates>~<SoftwareUpdates>1</SoftwareUpdates>~g' /qmf/config/config_happ_scsync.xml
	sed -i 's~<ElectricityDisplay>0</ElectricityDisplay>~<ElectricityDisplay>1</ElectricityDisplay>~g' /qmf/config/config_happ_scsync.xml
	sed -i 's~<GasDisplay>0</GasDisplay>~<GasDisplay>1</GasDisplay>~g' /qmf/config/config_happ_scsync.xml
	sed -i -e 's/\(<EndDate>\).*\(<\/EndDate>\)/<EndDate>-1<\/EndDate>/g' /qmf/config/config_happ_scsync.xml
}

removeNetworkErrorNotifications() {
	notificationsbarfile="/qmf/qml/qb/notifications/NotificationBar.qml"
	if ! grep -q "mod to remove" $notificationsbarfile
	then
		echo "Modification in NotificationBar.qml is missing. Fixing it now."
		sed -i '/function show/a\ //mod to remove network errors in notification bar\nnotifications.removeByTypeSubType("error","network");\n//end mod' $notificationsbarfile
	fi
}

installToonStoreApps() {
	#we assume that all symbolic linked dirs are toonstore installed apps - IS THAT OK?
	#toonstore is mandatory, if not yet installed, install it anyway
	for a in toonstore `find /qmf/qml/apps -type l | sed 's#/qmf/qml/apps/##' | grep -v toonstore`
	do
		latest=`curl -Nks --compressed $SOURCEFILES/apps/ToonRepo.xml | grep $a | grep folder | sed 's/.*<folder>\(.*\)<\/folder>.*/\1/'`
		if [ -n $latest ]
		then
			filename=`curl -Nks --compressed $SOURCEFILES/apps/$latest/Packages.gz | zcat | grep Filename| cut -d\  -f2`
			if [ -n $filename ] 
			then
				APPURL=$SOURCEFILES/apps/$latest/$filename
				opkg install $APPURL
			fi
		else
			echo "Could not find $a in toonstore repo!"
		fi

	done
}

installDropbear(){
	#install dropbear
	DROPBEARURL=$SOURCEFILES/dropbear_2015.71-r0_qb2.ipk
	opkg install $DROPBEARURL
}

installX11vnc(){
	if [ $ARCH == "nxt" ]
	then 
		echo "Not installing vnc for NXT yet. Not available in this version."
	else
		#uninstall current x11vnc
		opkg remove x11vnc
		/bin/sleep 5

		#install latest x11vnc
		X11VNCURL=$SOURCEFILES/x11vnc_0.9.13-r3_qb2.ipk
		opkg install $X11VNCURL
	fi
}

installBusybox() {
	VERS_MAJOR="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\1,p'`"
	VERS_MINOR="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\2,p'`"
	VERS_BUILD="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\3,p'`"

	#from version 4.9 and later we need to install a custom busybox as the native removes getty 
	if [ $VERS_MAJOR -gt 4 ] || [ $VERS_MAJOR -eq 4 -a $VERS_MINOR -ge 9 ]
	then 
		echo "Installing custom busybox to replace the native busybox from Eneco so we have a working getty."

		BUSYBOXURL=$SOURCEFILES/apps/busybox-1.27.2-r4/busybox_1.27.2-r4_qb2.ipk
		BUSYBOXMOUNTALLURL=$SOURCEFILES/apps/busybox-1.27.2-r4/busybox-mountall_1.27.2-r4_qb2.ipk
		BUSYBOXSYSLOGURL=$SOURCEFILES/apps/busybox-1.27.2-r4/busybox-syslog_1.27.2-r4_qb2.ipk

		opkg install $BUSYBOXURL
		opkg install $BUSYBOXMOUNTALLURL
		opkg install $BUSYBOXSYSLOGURL
	else
		echo "Custom busybox install not necessary for this firmware."
	fi
}

getVersion() {
	VERSIONS=`/usr/bin/curl -Nks --compressed "https://notepad.pw/raw/6fmm2o8ev" | /usr/bin/tr '\n\r' ' ' | /bin/grep STARTTOONVERSIONS | /bin/sed 's/.*#STARTTOONVERSIONS//' | /bin/sed 's/#ENDTOONVERSIONS.*//' | xargs`

	if [ "$VERSIONS" == "" ]
	then
		echo "Could not determine available versions from online sources. Using older well known verion list."
		#online versions list not available, falling back to a small well known list
		VERSIONS="2.9.26 3.0.29 3.0.32 3.1.22 3.2.14 3.2.18 3.3.8 3.4.4 3.5.4 3.6.3 3.7.8 3.7.9 4.3.20 4.4.21 4.7.23 4.8.25 4.9.23 4.10.6 4.11.6 4.12.0 4.13.6 4.13.7 4.15.2 4.15.6 4.16.8 4.18.8 4.19.10"
	fi

	#determine current version
	RUNNINGVERSION=`opkg list-installed base-$ARCH-\* | sed -r -e "s/base-$ARCH-([a-z]{3})\s-\s([0-9]*\.[0-9]*\.[0-9]*)-.*/\2/"`

	if echo $VERSIONS| grep -q $RUNNINGVERSION
	then
		echo "You are currently running version $RUNNINGVERSION on a $ARCH with flavour $FLAV"
	else
		echo "Unable to determine your current running version!"
		echo "DEBUG information:"
		echo "Detected: $RUNNINGVERSION"
		echo "Available: $VERSIONS"
		/usr/bin/opkg list-installed base-$ARCH-\*
		echo "END DEBUG information"
		if $UNATTENDED
		then
			/qmf/bin/bxt -d :happ_usermsg -s Notification -n CreateNotification -a type -v tsc -a subType -v notify -a text -v "Huidige Toon firmware onbekend. Kan geen nieuwe firmware hiervoor vinden." >/dev/null 2>&1
			echo "action=Failed&item=100&items=100&pkg=" > /tmp/update.status.vars
		fi
		exit
	fi

	echo ""
	echo "Available versions: $VERSIONS"
	echo ""
	if ! $UNATTENDED
	then
		echo "Which version do you want to upgrade to?" 
		read VERSION
		while [ "$VERSION" == "" ]  || ! ( echo $VERSION | grep -qe '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' )  || ! (echo $VERSIONS| grep -q $VERSION)
		do
			echo "Please enter a valid version!"
			read VERSION
		done
	else
		#determine latest version in unattended mode
		VERSION=${VERSIONS##* }	
		echo "Unattended selected version $VERSION"
	fi

	#determine current and next version levels and if it is allowed to upgrade to it
	CURVERS_MAJOR="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\1,p'`"
	CURVERS_MINOR="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\2,p'`"
	CURVERS_BUILD="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\3,p'`"
	VERS_MAJOR="`echo $VERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\1,p'`"
	VERS_MINOR="`echo $VERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\2,p'`"
	VERS_BUILD="`echo $VERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\3,p'`"

	if [ $VERS_MAJOR -gt $CURVERS_MAJOR ] || [ $VERS_MAJOR -eq $CURVERS_MAJOR -a $VERS_MINOR -gt $CURVERS_MINOR ] || [ $VERS_MAJOR -eq $CURVERS_MAJOR -a $VERS_MINOR -eq $CURVERS_MINOR -a $VERS_BUILD -gt $CURVERS_BUILD ]
	then
		if [ $CURVERS_MAJOR -ge 3 ] || [ $VERS_MAJOR -ge 3 -a $CURVERS_MAJOR -lt 3 -a "$RUNNINGVERSION" == "2.9.26" ] || [ $VERS_MAJOR -ge 3 -a $CURVERS_MAJOR -lt 3 -a $CURVERS_MINOR -ge 10 ] || [ $VERS_MAJOR -lt 3 ]
		then
			if  [ $VERS_MAJOR -le 4 -a $VERS_MINOR -le 10 ] || [ "$RUNNINGVERSION" == "4.10.6" ] ||  [ $CURVERS_MAJOR -ge 4 -a  $CURVERS_MINOR -ge 11  ] || [ $CURVERS_MAJOR -ge 5 ]
			then
				echo "Alright, I will try to upgrade to" $VERSION
			else
				echo "You need to upgrade to 4.10.6 first! Selecting this version for you."
				VERSION="4.10.6"

			fi
		else
			echo "You need to upgrade to 2.9.26 first! Selecting this version for you."
			VERSION="2.9.26"
		fi
	else
		if $UNATTENDED
		then
			/qmf/bin/bxt -d :happ_usermsg -s Notification -n CreateNotification -a type -v tsc -a subType -v notify -a text -v "Er is geen Toon firmware update gevonden" >/dev/null 2>&1
			echo "action=Failed&item=100&items=100&pkg=" > /tmp/update.status.vars
		else
			echo "Smartass.. "$VERSION" is not an upgrade for "$RUNNINGVERSION"!"
		fi
		exit

	fi
}

getArch() {
	#determine current architecture
	if grep -q nxt /etc/opkg/arch.conf
	then
		ARCH="nxt"
	else
		ARCH="qb2"
	fi
}

getFlav() {
	#determine current flavour
	FLAV=`opkg list-installed base-$ARCH-\* | sed -r -e "s/base-$ARCH-([a-z]{3})\s-\s([0-9]*\.[0-9]*\.[0-9]*)-.*/\1/"`
}

makeBackupUpdate() {
	#save current iptables config 
	/usr/sbin/iptables-save > /root/iptables.save

	#and backup the default iptables file and passwd file
	if [ ! -f /etc/default/iptables.conf ] 
	then 
		echo "Your default iptables.conf (firewall configuration) is missing. I will restore it from the current running firewall config."
		/usr/sbin/iptables-save > /etc/default/iptables.conf
	fi
	/bin/cp /etc/default/iptables.conf /root/iptables.backup
	if [ ! -f /etc/passwd ] 
	then
		echo "Your password file (/etc/passwd) is missing. Please fix this before running this script."
		exit
	fi
	/bin/cp /etc/passwd /root/passwd.backup 

	sync
}

makeBackupFixFiles() {
	#backup inittab
	echo creating backup of inittab...
	cp /etc/inittab /root/inittab.save

	#backup chrony.conf
	echo creating backup of chrony.conf...
	cp /etc/chrony.conf /root/chrony.save

	#backup hosts
	echo creating backup of hosts...
	cp /etc/hosts /root/hosts.save

	#backup scsync
	echo creating backup of config_happ_scsync.xml...
	cp /mnt/data/qmf/config/config_happ_scsync.xml /root/config_happ_scsync.save

	#backup qmf tenant file
	echo creating backup of qmf_tenant.xml.save ...
	cp /HCBv2/etc/qmf_tenant.xml /HCBv2/etc/qmf_tenant.xml.save

	sync
}

checkFixedFiles() {
	#check modified files for 0 size, if yes announce this and try to restore
	for file in /etc/inittab /etc/chrony.conf /etc/hosts /mnt/data/qmf/config/config_happ_scsync.xml /HCBv2/etc/qmf_tenant.xml
	do
		if [ ! -s $file ] 
		then
			echo "File $file was modified but result is an empty file! Trying to restore!"
			restorefile="$file.save"
			cp $restorefile $file
			sync
			if [ -s $file ] 
			then
				echo "Restore of $file is good. But modifying failed. Try to rerun the script with -f"
			else
				echo "Restore of $file is failed! Result is also empty! Please check this file before rebooting!"
			fi
		fi
	done
}

initializeFirewall() {
	#create a new iptables chain for this upgrade process and insert it in front of all rules
	/usr/sbin/iptables -N UPDATE-INPUT
	/usr/sbin/iptables -I INPUT -j UPDATE-INPUT

	#allow icmp (ping) always, or else openvpn will restart all the time do to internal toon ping checks
	/usr/sbin/iptables -A UPDATE-INPUT -p icmp -j ACCEPT
	#drop all VPN traffic (for now)
	/usr/sbin/iptables -A UPDATE-INPUT -i tap+ -j DROP
	/usr/sbin/iptables -A UPDATE-INPUT -i tun+ -j DROP
}

enableVPN() {
	#check if feed host is configured and there is a active route toward the host
	#if openvpn is already running we don't need to start it manually, the FEEDHOST and FEEDROUTE should match then
	FEEDHOST=`/bin/cat /etc/hosts | /bin/grep ^172 | /bin/grep feed | /usr/bin/awk 'BEGIN {FS="\t"}; {print $1}'| /usr/bin/awk 'BEGIN {FS="."}; {print $1"."$2"."$3}' `
	FEEDROUTE=`ip route | /bin/grep ^172.*via.*tap0 | /usr/bin/awk '{print $1}'| /usr/bin/awk 'BEGIN {FS="."}; {print $1"."$2"."$3}'`
	COUNT=0
	while [ ! "$FEEDHOST" == "$FEEDROUTE" ] || [ "$FEEDHOST" = "" ] || [ "$FEEDROUTE" == "" ] ; do
		if [ $COUNT -gt 5 ] 
		then
			echo "Could not enable VPN in a normal reasonable time!"
			echo "DEBUG information:"
			ip route
			/bin/cat /etc/hosts
			echo "END DEBUG information"
			exitFail
		fi
		COUNT=$((COUNT+1))
		/bin/echo "Now starting the VPN tunnel and waiting for it to be alive and configured..."
		/usr/sbin/openvpn --config /etc/openvpn/vpn.conf --verb 0 >/dev/null --daemon 
		/bin/sleep 5
		FEEDHOST=`/bin/cat /etc/hosts | /bin/grep ^172 | /bin/grep feed | /usr/bin/awk 'BEGIN {FS="\t"}; {print $1}'| /usr/bin/awk 'BEGIN {FS="."}; {print $1"."$2"."$3}' `
		FEEDROUTE=`ip route | /bin/grep ^172.*via.*tap0 | /usr/bin/awk '{print $1}'| /usr/bin/awk 'BEGIN {FS="."}; {print $1"."$2"."$3}'`
	done
	/bin/echo "Tunnel is alive and configured."
	#set the feedhost
	FEEDHOST=`/bin/cat /etc/hosts | /bin/grep ^172 | /bin/grep feed | /usr/bin/awk 'BEGIN {FS="\t"}; {print $1}'`
	#allow traffic from the vpn only from the feed host, and only if it is from the www port
	#this blocks other traffic, most important blocking the service center so other changes are not pushed
	/usr/sbin/iptables -I UPDATE-INPUT -p tcp -s $FEEDHOST -m tcp --sport 80 -j ACCEPT
}

downloadUpgradeFile() {
	#try to get the upgrade file from the feed host
	/usr/bin/wget  $SOURCE/$ARCH/upgrade/upgrade-$ARCH.sh -O $PKGCACHE/upgrade-$ARCH.sh -T 5 -t 2 -o /dev/null
	RESULT=$?

	if [ ! $RESULT == 0 ] ; then
		echo "Could not download the upgrade script from the source." 
		exitFail
	fi

	#check if there is a valid upgrade script
	if [ "$ARCH" == "nxt" ] 
	then
		MD5SCRIPT="9ba9beab205a2653d664b017b18e6d04"
	else
		MD5SCRIPT="0f1e14a01705e9c4deeca78ed9065037"
	fi
	MD5NOW=`/usr/bin/md5sum $PKGCACHE/upgrade-$ARCH.sh | cut -d\  -f1`
	if [ !  "$MD5NOW" == "$MD5SCRIPT" ]
	then
		echo "Warning: upgrade script from source server is changed. Do you want to continue downloading the files (if not sure, type no and report in the forums)?" 
		if ! $UNATTENDED ; then read QUESTION; fi	
		if [ ! "$QUESTION" == "yes" ] || $UNATTENDED  #also exit when untattended
		then
			exitFail
		fi
	fi

	#make sure the upgrade script doesn't reboot the device after finishing
	/bin/sed -i '/shutdown/c\#removed shutdown' $PKGCACHE/upgrade-$ARCH.sh 

	#removing the curl logging post to the servic center
	/bin/sed -i '/curl.*31080/c\#removed curl post to service center' $PKGCACHE/upgrade-$ARCH.sh

	#removing the pre exit BXT request (do not show restarting during update)
	/bin/sed -i 's/-n InitiatePreExit/-n InitiatePreExit -t/' $PKGCACHE/upgrade-$ARCH.sh

	#fixing /etc/hosts again so that toonstore can use it
	#and change the official feed host to feed.hae.orig
	sed -i 's/feed.hae.int/feed.hae.orig/' /etc/hosts
	echo '127.0.0.1  feed.hae.int  feed' >> /etc/hosts

	#rename the feed BASEURL host to the host we changed it to according to /etc/hosts 
	/bin/sed -i 's/feed.hae.int/feed.hae.orig/' $PKGCACHE/upgrade-$ARCH.sh 
}

startPrepare() {
	#temporary fix, sonos app issue cauasing updates to fail
	if opkg list-installed sonos | grep -q 1.0.4
	then
		echo "Sonos app 1.0.4 is being upgraded to 1.0.5 as it has issues causing problems with upgrading."
		/usr/bin/opkg install http://files.domoticaforum.eu/uploads/Toon/apps/sonos-1.0.5/sonos_1.0.5-r0_qb2.ipk >/dev/null 2>&1	
	fi

	echo "Upgrade script downloaded. We need to download the upgrade files first. No upgrade is done yet. Do you want me to download the files (yes) or quit (anything else)?"
	if ! $UNATTENDED ; then read QUESTION; fi	
	if [ ! "$QUESTION" == "yes" ] 
	then
		exitFail
	fi

	echo "Starting the upgrade prepare option which downloads all necessary files. No upgrade is done yet."

	/bin/sh $PKGCACHE/upgrade-$ARCH.sh $ARCH $FLAV $VERSION prepare &
	DOWNLOAD_PID=$!
	showStatus $DOWNLOAD_PID

	if ! wait $DOWNLOAD_PID
	then
		echo "Prepare failed. Please check the logs at $PKGCACHE/upgrade-$ARCH.sh.log"
		exitFail
	fi

	echo "Done preparing."

	#check disk size after download
	FREESPACE=`df $PKGCACHE | awk '/[0-9]%/{print $(NF-2)}'`
	if [ $FREESPACE -lt 5000 ] 
	then
		echo "After downloading the files the free space on the Toon is less then 5000 KB. This could cause the upgrade to fail. Do you still want to continue (yes)?"
		if ! $UNATTENDED ; then read QUESTION; fi	
		if [ ! "$QUESTION" == "yes" ]  || $UNATTENDED #fail if unattended
		then
			exitFail
		fi
	fi
}

startUpgrade() {
	echo "Are your sure you want to upgrade to" $VERSION" (yes)? This is the last moment you can stop the upgrade. Answer with 'yes' will start the upgrade."
	if ! $UNATTENDED ; then read QUESTION; fi	
	if [ ! "$QUESTION" == "yes" ] 
	then
		exitFail
	fi

	echo "Starting the upgrade now! Just wait a while... It can take a few minutes."

	/bin/sh $PKGCACHE/upgrade-$ARCH.sh $ARCH $FLAV $VERSION execute &
	UPGRADE_PID=$!
	showStatus $UPGRADE_PID

	if ! wait $UPGRADE_PID
	then
		echo "Upgrade failed. Please check the logs at $PKGCACHE/upgrade-$ARCH.sh.log"
		exitFail
	fi

	echo "Upgrade done!" 
}

showStatus() {
	STATUS_PID=$1
	DOTS="   ..."
	PERC=0
	SECONDS=0
	while [ $PERC -lt 100 ] && [ -e /proc/$STATUS_PID ] && [ $SECONDS -lt 900 ]
	do
		PERC="`sed /tmp/update.status.vars -n -r -e 's,^.+item=(.+?)&items=(.+?)&.+$,\1,p' 2>/dev/null`"
		PERC="${PERC:-0}"

		# do not append newline, \r to beginning of line after print, append space to overwrite prev-longer-sentences
		echo -n -e "Progress: $PERC% ${DOTS:0:3}    \r"

		# shift right
		DOTS="${DOTS:5:1}${DOTS:0:5}"
		sleep 1 >/dev/null 2>&1 || read -t 1 < /dev/tty5  #during busybox update sleep fails, so failover to read with 1 sec timeout, tty5 never gives any input
		SECONDS=$((SECONDS+1))
	done

	while [ -e /proc/$STATUS_PID ] && [ $SECONDS -lt 900 ]
	do
		echo -n -e "Waiting to finish. Sometimes this takes a minute or two  ${DOTS:0:3}    \r"
		DOTS="${DOTS:5:1}${DOTS:0:5}"
		sleep 1 >/dev/null 2>&1 || read -t 1  < /dev/tty5  #during busybox update sleep fails, so failover to read with 1 sec timeout, tty5 never gives any input
		SECONDS=$((SECONDS+1))
	done


	if [ $SECONDS -ge 900 ]
	then
		kill -9 $STATUS_PID
		echo "Killing process... took to long!"
	fi

	echo ""
	rm -f /tmp/update.status.vars
}

restoreBackup() {
	echo "Restoring your iptables and passwd files so you can login again after rebooting."
	/bin/cp /root/iptables.backup /etc/default/iptables.conf
	/bin/cp /root/passwd.backup /etc/passwd 

	#cleaning up
	/usr/bin/killall -9 openvpn
	/usr/sbin/iptables-restore <  /root/iptables.save

	sync
}

exitFail() {
	echo "Quitting the upgrade. It was a nice try tho..."
	/usr/bin/killall -9 openvpn
	/usr/sbin/iptables-restore <  /root/iptables.save
	if $UNATTENDED
	then
		/qmf/bin/bxt -d :happ_usermsg -s Notification -n CreateNotification -a type -v tsc -a subType -v notify -a text -v "Er ging iets mis bij het updaten van Toon Firmware. Controleer logs." >/dev/null 2>&1
		echo "action=Failed&item=100&items=100&pkg=" > /tmp/update.status.vars
	fi
	exit
}

downloadResourceFile() {
	RESOURCEFILEURL="http://qutility.nl/resourcefiles/resources-$ARCH-$RUNNINGVERSION.zip"
	/usr/bin/wget  $RESOURCEFILEURL -O /tmp/resources-$ARCH-$RUNNINGVERSION.zip -T 5 -t 2 -o /dev/null
	RESULT=$?

	if [ ! $RESULT == 0 ]
	then 
		echo "Could not download a resources.rcc file for this version! Continuing, but your custom apps probably dont work anymore" 
	else 
		mv /qmf/qml/resources-static-base.rcc /qmf/qml/resources-static-base.rcc.backup
		mv /qmf/qml/resources-static-ebl.rcc /qmf/qml/resources-static-ebl.rcc.backup
		/usr/bin/unzip -oq /tmp/resources-$ARCH-$RUNNINGVERSION.zip -d /qmf/qml
	fi
	#install boot script to download TSC helper script if necessary
	echo "if [ ! -s /usr/bin/tsc ] || grep -q no-check-certificate /usr/bin/tsc ; then /usr/bin/curl -Nks --retry 5 --connect-timeout 2 https://raw.githubusercontent.com/IgorYbema/tscSettings/master/tsc -o /usr/bin/tsc ; chmod +x /usr/bin/tsc ; fi ; if ! grep -q tscs /etc/inittab ; then sed -i '/qtqt/a\ tscs:245:respawn:/usr/bin/tsc >/var/log/tsc 2>&1' /etc/inittab ; if grep tscs /etc/inittab ; then reboot ; fi ; fi" > /etc/rc5.d/S99tsc.sh
	#download TSC helper script
	if [ ! -s /usr/bin/tsc ] || grep -q no-check-certificate /usr/bin/tsc
	then
		/usr/bin/curl --compressed -Nks  --retry 5 --connect-timeout 2 https://raw.githubusercontent.com/IgorYbema/tscSettings/master/tsc -o /usr/bin/tsc
		chmod +x /usr/bin/tsc
	fi
	#install tsc in inittab to run continously from boot
	if ! grep -q tscs /etc/inittab
	then
		sed -i '/qtqt/a\tscs:245:respawn:/usr/bin/tsc >/var/log/tsc 2>&1' /etc/inittab
	fi
}

overrideFirewallAlways () {
	echo "sed -i '/-A INPUT -j HCB-INPUT/a\#override to allow all input\n-I INPUT -j ACCEPT' /etc/default/iptables.conf" > /etc/rcS.d/S39fixiptables
	/bin/chmod +x /etc/rcS.d/S39fixiptables
}

fixFiles() {
	#get the current, just installed, version (also necessary when -f is called)
	RUNNINGVERSION=`opkg list-installed base-$ARCH-\* | sed -r -e "s/base-$ARCH-([a-z]{3})\s-\s([0-9]*\.[0-9]*\.[0-9]*)-.*/\2/"`
	VERS_MAJOR="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\1,p'`"
	VERS_MINOR="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\2,p'`"
	VERS_BUILD="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\3,p'`"

	if [ $ARCH == "nxt" ]
	then 
		#from version 4.16 we need to download resources.rcc mod
		if [ $VERS_MAJOR -gt 4 ] || [ $VERS_MAJOR -eq 4 -a $VERS_MINOR -ge 16 ]
		then 
			echo "FIXING: Downloading resources.rcc TSC mod for this version $RUNNINGVERSION."
			downloadResourceFile
		else 
			echo "FIXING: Trying to fix Global.qml now to add all the Toonstore installed apps again." 
			fixGlobalsFile
			echo "FIXING: Now fixing internet settings app to fake ST_TUNNEL mode."
			fixInternetSettingsApp
			echo "FIXING: Now modifying notifications bar to not show any network errors" 
			removeNetworkErrorNotifications
		fi
		echo "FIXING: Now updating all toonstore installed apps"
		installToonStoreApps
		#dropbear is not needed, no rooted toon2 without working dropbear exists
		#echo "FIXING: Installing Dropbear for ssh access"
		#installDropbear
		echo "EDITING: Time server, removes unnecessary link to Quby"
		editTimeServer
		echo "EDITING: Hosts file, removes unnecessary link to Quby"
		editHostfile
		echo "EDITING: disable ovpn connection to quby"
		editVPNconnection
		echo "EDITING: Activating Toon, enabling ElectricityDisplay and GasDisplay"
		editActivation
		echo "EDITING: removing data gathering by Quby and whitelisting web services" 
		editQMFConfigFile
		echo "EDITING: add disable power management wifi on Toon2" 
		editWifiPM
	else
		#from version 4.16 we need to download resources.rcc mod
		if [ $VERS_MAJOR -gt 4 ] || [ $VERS_MAJOR -eq 4 -a $VERS_MINOR -ge 16 ]
		then 
			echo "FIXING: Downloading resources.rcc TSC mod for this version $RUNNINGVERSION."
			downloadResourceFile
		else 
			echo "FIXING: Trying to fix Global.qml now to add all the Toonstore installed apps again." 
			fixGlobalsFile
			echo "FIXING: Now fixing internet settings app to fake ST_TUNNEL mode."
			fixInternetSettingsApp
			echo "FIXING: Now modifying notifications bar to not show any network errors" 
			removeNetworkErrorNotifications
		fi
		echo "FIXING: Now updating all toonstore installed apps"
		installToonStoreApps
		#busybox update disabled due to issues
		#echo "FIXING: Now installing latest busybox mod. This is necessary to enable console output again which is disabled in 4.10 by Eneco." 
		#installBusybox
		echo "FIXING: Installing Dropbear for ssh access"
		installDropbear
		echo "EDITING: Time server, removes unnecessary link to Quby"
		editTimeServer
		echo "EDITING: Hosts file, removes unnecessary link to Quby"
		editHostfile
		echo "EDITING: disable ovpn connection to quby"
		editVPNconnection
		echo "EDITING: Adding serial connection"
		editSerialConnection
		echo "EDITING: Activating Toon, enabling ElectricityDisplay and GasDisplay"
		editActivation
		echo "EDITING: removing data gathering by Quby and whitelisting web services" 
		editQMFConfigFile
	fi
}

#main

UNATTENDED=false
STEP=0
VERSION=""
SOURCE="http://feed.hae.int/feeds"
SOURCEFILES="http://files.domoticaforum.eu/uploads/Toon"
ENABLEVPN=true
PROGARGS="$@"


#get options
while getopts ":v:s:abfduh" opt $PROGARGS
do
	case $opt in
		v)
			echo "Forcing version: $OPTARG"
			VERSION=$OPTARG
			;;
		s)
			echo "Forcing source: $OPTARG"
			SOURCE=$OPTARG
			;;
		a)
			echo "Auto activation"
			editActivation
			exit
			;;
		b)
			echo "Busybox installation"
			installBusybox
			exit
			;;
		u)
			echo "Unattended mode"
			UNATTENDED=true
			QUESTION="yes"
			;;
		d)
			echo "Skip starting VPN"
			ENABLEVPN=false
			;;
		f)
			echo "Only fixing files."
			getArch
			makeBackupUpdate
			makeBackupFixFiles
			fixFiles
			checkFixedFiles
			exit
			;;
		h)      usage
			exit 1
			;;
		\?)
			echo "Invalid option: -$OPTARG"
			exit
			;;
	esac
done

#get recent version of this script
autoUpdate $PROGARGS

#determine where this Toon is storing the update files
PKGCACHE='/mnt/data/update'
if ! strings /HCBv2/sbin/hcb_config | grep -q -e "^${PKGCACHE}\$"
then
	#this toon still uses the old PKGCACHE
	PKGCACHE='/HCBv2/tmp/opkg-cache'
fi
#check if the cache dir is already there, create it otherwise (should normally be there always)
if [ ! -d $PKGCACHE ] 
then
	mkdir -p $PKGCACHE
fi

STATUSFILE="$PKGCACHE/updated-rooted.status"
#check previous running script
if [ -f $STATUSFILE ]  && ! $UNATTENED #no resume in unattended mode
then
	echo "Detected an unclean abort of previous running update script. Do you want me to resume (yes) or restart (no)?"
	read RESUME
	if [ "$RESUME" == "yes" ] 
	then 
		echo "Ok, resuming. Trying to determine last step."
		STEP=`cat $PKGCACHE/updated-rooted.status | sed -n -r -e 's,([0-9]+);([0-9]+\.[0-9]+\.[0-9]+);(.*);(.*),\1,p'`
		VERSION=`cat $PKGCACHE/updated-rooted.status | sed -n -r -e 's,([0-9]+);([0-9]+\.[0-9]+\.[0-9]+);(.*);(.*),\2,p'`
		FLAV=`cat $PKGCACHE/updated-rooted.status | sed -n -r -e 's,([0-9]+);([0-9]+\.[0-9]+\.[0-9]+);(.*);(.*),\3,p'`
		ARCH=`cat $PKGCACHE/updated-rooted.status | sed -n -r -e 's,([0-9]+);([0-9]+\.[0-9]+\.[0-9]+);(.*);(.*),\4,p'`
		echo "Resuming at step $STEP and we where installing version $VERSION with flavour $FLAV in a $ARCH system"
	fi
	# remove statusfile so we don't restart at the same point the next time
	rm -f $STATUSFILE
fi

if [ $STEP -lt 1 ] 
then
	STEP=1;
	#get the architecture
	getArch
	#get the current flavour
	getFlav
	#we need to determine current version and to which version we want to upgrade to
	if [ "$VERSION" == "" ]
	then 
		getVersion
	fi
	echo "$STEP;$VERSION;$FLAV;$ARCH" > $STATUSFILE
fi

if [ $STEP -lt 2 ] 
then
	STEP=2;
	#then we make a backup of some important files, just to be sure
	makeBackupUpdate
	echo "$STEP;$VERSION;$FLAV;$ARCH" > $STATUSFILE
fi

#even if we resume we need to make sure we have the firewall in place and renable the VPN
#before opening the connection to Eneco's network we prepare the firewall to only allow access from/to the download server
if $ENABLEVPN
then
	initializeFirewall
	#now we are ready to try to start the VPN
	enableVPN
fi

if [ $STEP -lt 3 ] 
then
	STEP=3;
	#we are ready to downlaod the eneco upgrade script
	downloadUpgradeFile
	echo "$STEP;$VERSION;$FLAV;$ARCH" > $STATUSFILE
fi

if [ $STEP -lt 4 ] 
then
	STEP=4;
	#if the script is ok, we start downloading the updates (prepare)
	startPrepare
	echo "$STEP;$VERSION;$FLAV;$ARCH" > $STATUSFILE
fi

if [ $STEP -lt 5 ] 
then
	STEP=5;
	#and if that is succesfull we start the upgrade
	startUpgrade
	echo "$STEP;$VERSION;$FLAV;$ARCH" > $STATUSFILE
fi


if [ $STEP -lt 6 ] 
then
	STEP=6;
	#finally we restore the important files
	restoreBackup
	echo "$STEP;$VERSION;$FLAV;$ARCH" > $STATUSFILE
fi


if [ $STEP -lt 7 ]
then
	STEP=7;
	#some other fixing needs to be done after an upgrade
	echo "Upgrade is done. However each firmware upgrade will revert the changes to some files needed for a working rooted Toon. Do you want me me to try and fix a few well known issue's for you right now?"
	if ! $UNATTENDED ; then read QUESTION ; fi
	if [ "$QUESTION" == "yes" ] 
	then
		makeBackupFixFiles
		fixFiles
		checkFixedFiles
	fi
	echo "$STEP;$VERSION;$FLAV;$ARCH" > $STATUSFILE
fi
if [ $STEP -lt 8 ]
then
	STEP=8;
	#some other fixing needs to be done after an upgrade
	echo "Do you want to install x11vnc? cmd 'x11vnc' needs to be run after each reboot to start the x11vnc server. x11vnc password can be set while starting x11vnc for the first time"
	if ! $UNATTENDED ; then read QUESTION ; fi
	if [ "$QUESTION" == "yes" ] &&  ! $UNATTENDED #not install x11vnc in unattended mode
	then
		installX11vnc
	fi
fi

# sync the filesystem
sync ; sync

echo "Everything done! You should reboot now!"

#remove statusfile
rm -f $STATUSFILE

if $UNATTENDED
then
	#reboot in autattended mode
	shutdown -r now
fi
