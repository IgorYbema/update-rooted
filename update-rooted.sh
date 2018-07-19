#!/bin/sh

echo "==================================================================================================================================================================="
echo "Welcome to the rooted Toon upgrade script. This script will try to upgrade your Toon using your original connection with Eneco. It will start the VPN if necessary."
echo "Please be advised that running this script is at your own risk!"
echo ""
echo "Version: 2.94  - ThehogNL - 19-7-2018"
echo ""
echo "==================================================================================================================================================================="
echo ""

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

removeNetworkErrorNotifications() {
	notificationsbarfile="/qmf/qml/qb/notifications/NotificationBar.qml"
	if ! grep -q "mod to remove" $notificationsbarfile
	then
		echo "Modification in NotificationBar.qml is missing. Fixing it now."
		sed -i '/function show/a\ //mod to remove network errors in notification bar\nnotifications.removeByTypeSubType("error","network");\n//end mod' $notificationsbarfile
	fi
}

installToonStore() {
	BASEURL="http://files.domoticaforum.eu/uploads/Toon/apps/"

	latest=`curl -Nks $BASEURL/ToonRepo.xml | grep toonstore | grep folder | sed 's/.*<folder>\(.*\)<\/folder>.*/\1/'`
	filename=`curl -Nks $BASEURL/$latest/Packages.gz | zcat | grep Filename| cut -d\  -f2`

	installurl="$BASEURL/$latest/$filename"
	opkg install $installurl
}

installBusybox() {
	VERS_MAJOR="`echo $VERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\1,p'`"
	VERS_MINOR="`echo $VERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\2,p'`"
	VERS_BUILD="`echo $VERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\3,p'`"

	#from version 4.9 and later we need to install a custom busybox as the native removes getty 
	if [ $VERS_MAJOR -gt 4 ] || [ $VERS_MAJOR -eq 4 -a $VERS_MINOR -ge 9 ]
	then 
		echo "Installing custom busybox to replace the native busybox from Eneco so we have a working getty."

		BUSYBOXURL="http://files.domoticaforum.eu/uploads/Toon/apps/busybox-1.27.2-r4/busybox_1.27.2-r4_qb2.ipk"
		BUSYBOXMOUNTALLURL="http://files.domoticaforum.eu/uploads/Toon/apps/busybox-1.27.2-r4/busybox-mountall_1.27.2-r4_qb2.ipk"
		BUSYBOXSYSLOGURL="http://files.domoticaforum.eu/uploads/Toon/apps/busybox-1.27.2-r4/busybox-syslog_1.27.2-r4_qb2.ipk"

		opkg install $BUSYBOXURL
		opkg install $BUSYBOXMOUNTALLURL
		opkg install $BUSYBOXSYSLOGURL
	else
		echo "Custom busybox install not necessary for this firmware."
	fi
}



getVersion() {

	#get versions from tor source doesnt work properly
	#VERSIONS=`/usr/bin/curl -Nks "https://smauhhl7uskcgtro.tor2web.io/feeds/qb2/versions.$FLAV"` 

	VERSIONS=`/usr/bin/curl -Nks "https://notepad.pw/raw/6fmm2o8ev" | /usr/bin/tr '\n\r' ' ' | /bin/grep STARTTOONVERSIONS | /bin/sed 's/.*#STARTTOONVERSIONS//' | /bin/sed 's/#ENDTOONVERSIONS.*//'`


	if [ "$VERSIONS" == "" ]
	then
		echo "Could not determine available versions from online sources. Using older well known verion list."
		#online versions list not available, falling back to a small well known list
		VERSIONS="2.9.26 3.0.29 3.0.32 3.1.22 3.2.14 3.2.18 3.3.8 3.4.4 3.5.4 3.6.3 3.7.8 3.7.9 4.3.20 4.4.21 4.7.23 4.8.25 4.9.23 4.10.6 4.11.6 4.12.0 4.13.6 4.13.7"
	fi

	#determine current version
	RUNNINGVERSION=`opkg list-installed base-qb2-\* | sed -r -e "s/base-qb2-([a-z]{3})\s-\s([0-9]*\.[0-9]*\.[0-9]*)-.*/\2/"`

	if echo $VERSIONS| grep -q $RUNNINGVERSION
	then
		echo "You are currently running version "$RUNNINGVERSION
	else
		echo "Unable to determine your current running version!"
		echo "DEBUG information:"
		echo "Detected: $RUNNINGVERSION"
		echo "Available: $VERSIONS"
		/usr/bin/opkg list-installed base-qb2-\*
		echo "END DEBUG information"
		exit
	fi

	echo ""
	echo "Available versions: $VERSIONS"
	echo ""
	echo "Which version do you want to upgrade to?" 
	read VERSION
	while [ "$VERSION" == "" ]  || ! ( echo $VERSION | grep -qe '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' )  || ! (echo $VERSIONS| grep -q $VERSION)
	do
		echo "Please enter a valid version!"
		read VERSION
	done


	#determine current and next version levels and if it is allowed to upgrade to it

	CURVERS_MAJOR="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\1,p'`"
	CURVERS_MINOR="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\2,p'`"
	CURVERS_BUILD="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\3,p'`"
	VERS_MAJOR="`echo $VERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\1,p'`"
	VERS_MINOR="`echo $VERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\2,p'`"
	VERS_BUILD="`echo $VERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\3,p'`"

	if [ $VERS_MAJOR -gt $CURVERS_MAJOR ] || [ $VERS_MAJOR -eq $CURVERS_MAJOR -a $VERS_MINOR -gt $CURVERS_MINOR ] || [ $VERS_MAJOR -eq $CURVERS_MAJOR -a $VERS_MINOR -eq $CURVERS_MINOR -a $VERS_BUILD -gt $CURVERS_BUILD ]
	then
		if [ $CURVERS_MAJOR -ge 3 ] || [ $VERS_MAJOR -ge 3 -a $CURVERS_MAJOR -lt 3 -a "$RUNNINGVERSION" == "2.9.26" ] || [ $VERS_MAJOR -lt 3 ]
		then
			if  [ $VERS_MAJOR -le 4 -a $VERS_MINOR -le 10 ] || [ $VERS_MAJOR -ge 4 -a $VERS_MINOR -ge 11 -a "$RUNNINGVERSION" == "4.10.6" ] ||  [ $CURVERS_MAJOR -ge 4 -a  $CURVERS_MINOR -ge 11  ]
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
		echo "Smartass.. "$VERSION" is not an upgrade for "$RUNNINGVERSION"!"
		exit
	fi
}

getFlav() {

	#determine current flavour
	FLAV=`opkg list-installed base-qb2-\* | sed -r -e "s/base-qb2-([a-z]{3})\s-\s([0-9]*\.[0-9]*\.[0-9]*)-.*/\1/"`

}

makeBackup() {
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
	FEEDROUTE=`/bin/ip route | /bin/grep ^172.*via.*tap0 | /usr/bin/awk '{print $1}'| /usr/bin/awk 'BEGIN {FS="."}; {print $1"."$2"."$3}'`
	COUNT=0
	while [ ! "$FEEDHOST" == "$FEEDROUTE" ] || [ "$FEEDHOST" = "" ] || [ "$FEEDROUTE" == "" ] ; do
		if [ $COUNT -gt 5 ] 
		then
			echo "Could not enable VPN in a normal reasonable time!"
			echo "DEBUG information:"
			/bin/ip route
			/bin/cat /etc/hosts
			echo "END DEBUG information"
			exitFail
		fi
		COUNT=$((COUNT+1))
		/bin/echo "Now starting the VPN tunnel and waiting for it to be alive and configured..."
		/usr/sbin/openvpn --config /etc/openvpn/vpn.conf --verb 0 >/dev/null --daemon 
		/bin/sleep 5
		FEEDHOST=`/bin/cat /etc/hosts | /bin/grep ^172 | /bin/grep feed | /usr/bin/awk 'BEGIN {FS="\t"}; {print $1}'| /usr/bin/awk 'BEGIN {FS="."}; {print $1"."$2"."$3}' `
		FEEDROUTE=`/bin/ip route | /bin/grep ^172.*via.*tap0 | /usr/bin/awk '{print $1}'| /usr/bin/awk 'BEGIN {FS="."}; {print $1"."$2"."$3}'`
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
	/usr/bin/wget  $SOURCE/qb2/upgrade/upgrade-qb2.sh -O $PKGCACHE/upgrade-qb2.sh -T 5 -t 2 -o /dev/null
	RESULT=$?

	if [ ! $RESULT == 0 ] ; then
		echo "Could not download the upgrade script from the source." 
		exitFail
	fi

	#check if there is a valid upgrade script
	MD5SCRIPT="b60d912b2a6cf8400b4405ffc9153e10"
	MD5NOW=`/usr/bin/md5sum $PKGCACHE/upgrade-qb2.sh | cut -d\  -f1`
	if [ !  "$MD5NOW" == "$MD5SCRIPT" ]
	then
		echo "Warning: upgrade script from source server is changed. Do you want to continue downloading the files (if not sure, type no and report in the forums)?" 
		read QUESTION
		if [ ! "$QUESTION" == "yes" ] 
		then
			exitFail
		fi
	fi

	#make sure the upgrade script doesn't reboot the device after finishing
	/bin/sed -i '/shutdown/c\#removed shutdown' $PKGCACHE/upgrade-qb2.sh 

        #removing the curl logging post to the servic center
        /bin/sed -i '/curl.*31080/c\#removed curl post to service center' $PKGCACHE/upgrade-qb2.sh


	#fixing /etc/hosts again so that toonstore can use it
	#and change the official feed host to feed.hae.orig
	sed -i 's/feed.hae.int/feed.hae.orig/' /etc/hosts
	echo '127.0.0.1  feed.hae.int  feed' >> /etc/hosts

	#rename the feed BASEURL host to the host we changed it to according to /etc/hosts 
	/bin/sed -i 's/feed.hae.int/feed.hae.orig/' $PKGCACHE/upgrade-qb2.sh 


}

startPrepare() {
	echo "Upgrade script downloaded. We need to download the upgrade files first. No upgrade is done yet. Do you want me to download the files (yes) or quit (anything else)?"
	read QUESTION
	if [ ! "$QUESTION" == "yes" ] 
	then
		exitFail
	fi

	echo "Starting the upgrade prepare option which downloads all necessary files. No upgrade is done yet."

	/usr/bin/timeout -t 600 /bin/sh $PKGCACHE/upgrade-qb2.sh qb2 $FLAV $VERSION prepare &
	DOWNLOAD_PID=$!
	showStatus $DOWNLOAD_PID

	if ! wait $DOWNLOAD_PID
	then
		echo "Prepare failed. Please check the logs at $PKGCACHE/upgrade-qb2.sh.log"
		exitFail
	fi

	echo "Done preparing."

	#check disk size after download
	FREESPACE=`df $PKGCACHE | awk '/[0-9]%/{print $(NF-2)}'`
	if [ $FREESPACE -lt 5000 ] 
	then
		echo "After downloading the files the free space on the Toon is less then 5000 KB. This could cause the upgrade to fail. Do you still want to continue (yes)?"
		read QUESTION
		if [ ! "$QUESTION" == "yes" ] 
		then
			exitFail
		fi
	fi
}

startUpgrade() {

	echo "Are your sure you want to upgrade to" $VERSION" (yes)? This is the last moment you can stop the upgrade. Answer with 'yes' will start the upgrade."
	read QUESTION
	if [ ! "$QUESTION" == "yes" ] 
	then
		exitFail
	fi

        echo "Starting the upgrade now! Just wait a while... It can take a few minutes."

	/usr/bin/timeout -t 1800 /bin/sh $PKGCACHE/upgrade-qb2.sh qb2 $FLAV $VERSION execute &
	UPGRADE_PID=$!
	showStatus $UPGRADE_PID

	if ! wait $UPGRADE_PID
	then
		echo "Upgrade failed. Please check the logs at $PKGCACHE/upgrade-qb2.sh.log"
		exitFail
	fi

	echo "Upgrade done!" 

}


showStatus() {
	STATUS_PID=$1
        DOTS="   ..."
        PERC=0
        while [ $PERC -lt 100 ] && [ -e /proc/$STATUS_PID ]
        do
                PERC="`sed /tmp/update.status.vars -n -r -e 's,^.+item=(.+?)&items=(.+?)&.+$,\1,p' 2>/dev/null`"
                PERC="${PERC:-0}"

                # do not append newline, \r to beginning of line after print, append space to overwrite prev-longer-sentences
                echo -n -e "Progress: $PERC% ${DOTS:0:3}    \r"

                # shift right
                DOTS="${DOTS:5:1}${DOTS:0:5}"
		sleep 1
        done

	while [ -e /proc/$STATUS_PID ]
	do
		echo -n -e "Waiting to finish. Sometimes this takes a minute or two  ${DOTS:0:3}    \r"
                DOTS="${DOTS:5:1}${DOTS:0:5}"
		sleep 1
	done
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
	exit
}

downloadResourceFile() {
	RESOURCEFILEURL="http://files.domoticaforum.eu/uploads/Toon/resourcefiles/resources-qb2-$RUNNINGVERSION.zip"
	/usr/bin/wget  $RESOURCEFILEURL -O /tmp/resources-qb2-$RUNNINGVERSION.zip -T 5 -t 2 -o /dev/null
	RESULT=$?

	if [ ! $RESULT == 0 ]
	then 
		echo "Could not download a resources.rcc file for this version! Continuing, but your custom apps probably dont work anymore" 
	else 
		mv /qmf/qml/resources-static-base.rcc /qmf/qml/resources-static-base.rcc.backup
		/usr/bin/unzip -oq /tmp/resources-qb2-$RUNNINGVERSION.zip -d /qmf/qml
	fi
}

overrideFirewallAlways () {

	echo "sed -i '/-A INPUT -j HCB-INPUT/a\#override to allow all input\n-I INPUT -j ACCEPT' /etc/default/iptables.conf" > /etc/rcS.d/S39fixiptables
	/bin/chmod +x /etc/rcS.d/S39fixiptables


}

fixFiles() {
	RUNNINGVERSION=`opkg list-installed base-qb2-\* | sed -r -e "s/base-qb2-([a-z]{3})\s-\s([0-9]*\.[0-9]*\.[0-9]*)-.*/\2/"`
	VERS_MAJOR="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\1,p'`"
	VERS_MINOR="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\2,p'`"
	VERS_BUILD="`echo $RUNNINGVERSION | sed -n -r -e 's,([0-9]+).([0-9]+).([0-9]+),\3,p'`"

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
	echo "FIXING: Now installing latest toonstore app. This fixes some files also."
	installToonStore
	echo "FIXING: Now installing latest busybox mod. This is necessary to enable console output again which is disabled in 4.10 by Eneco." 
	installBusybox
}

#main
STEP=0
VERSION=""
SOURCE="http://feed.hae.int/feeds"
ENABLEVPN=true

#get options
while getopts ":v:s:fd" opt 
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
		d)
			echo "Skip starting VPN"
			ENABLEVPN=false
			;;
		f)
			echo "Only fixing files."
			fixFiles
			exit	
			;;
		\?)
			echo "Invalid option: -$OPTARG"
			exit
			;;
	esac
done

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
if [ -f $STATUSFILE ] 
then
	echo "Detected an unclean abort of previous running update script. Do you want me to resume (yes) or restart (no)?"
	read RESUME
	if [ "$RESUME" == "yes" ] 
	then 
		echo "Ok, resuming. Trying to determine last step."
		STEP=`cat $PKGCACHE/updated-rooted.status | sed -n -r -e 's,([0-9]+);([0-9]+\.[0-9]+\.[0-9]+);(.*),\1,p'`
		VERSION=`cat $PKGCACHE/updated-rooted.status | sed -n -r -e 's,([0-9]+);([0-9]+\.[0-9]+\.[0-9]+);(.*),\2,p'`
		FLAV=`cat $PKGCACHE/updated-rooted.status | sed -n -r -e 's,([0-9]+);([0-9]+\.[0-9]+\.[0-9]+);(.*),\3,p'`
		echo "Resuming at step $STEP and we where installing version $VERSION with flavour $FLAV"
	fi
	# remove statusfile so we don't restart at the same point the next time
	rm -f $STATUSFILE
fi

if [ $STEP -lt 1 ] 
then
	STEP=1;
	#get the current flavour
	getFlav
	#we need to determine current version and to which version we want to upgrade to
	if [ "$VERSION" == "" ]
	then 
		getVersion
	fi
	echo "$STEP;$VERSION;$FLAV" > $STATUSFILE
fi

if [ $STEP -lt 2 ] 
then
	STEP=2;
	#then we make a backup of some important files, just to be sure
	makeBackup
	echo "$STEP;$VERSION;$FLAV" > $STATUSFILE
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
	echo "$STEP;$VERSION;$FLAV" > $STATUSFILE
fi

if [ $STEP -lt 4 ] 
then
	STEP=4;
	#if the script is ok, we start downloading the updates (prepare)
	startPrepare
	echo "$STEP;$VERSION;$FLAV" > $STATUSFILE
fi

if [ $STEP -lt 5 ] 
then
	STEP=5;
	#and if that is succesfull we start the upgrade
	startUpgrade
	echo "$STEP;$VERSION;$FLAV" > $STATUSFILE
fi


if [ $STEP -lt 6 ] 
then
	STEP=6;
	#finally we restore the important files
	restoreBackup
	echo "$STEP;$VERSION;$FLAV" > $STATUSFILE
fi


if [ $STEP -lt 7 ] 
then
	STEP=7;
	#some other fixing needs to be done after an upgrade
	echo "Upgrade is done. However each firmware upgrade will revert the changes to some files needed for a working rooted Toon. Do you want me me to try and fix a few well known issue's for you right now?"
	read QUESTION
	if [ "$QUESTION" == "yes" ] 
	then
	fixFiles
	fi
	echo "$STEP;$VERSION;$FLAV" > $STATUSFILE
fi

echo "Everything done! You should reboot now! But before that take some time to check if your /etc/passwd file is still valid (contains encrypted password for user root) and if /etc/default/iptables.conf is not blocking SSH access."

#remove statusfile
rm -f $STATUSFILE
