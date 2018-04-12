# Update a rooted Toon 

When running this script on a rooted Toon (thermostat from Eneco - the Netherlands) it will try to connect to the Eneco VPN and upgrade your toon to the version you specify.
It will backup and repair important files which are overwritten by the upgrade. Also, it will block any other traffic over the VPN so no unwanted service center messages are received or transfered.

The script eventually uses the Toon original sources to upgrade the Toon so there is a good chance the upgrade works fine. However sometimes upgrade fails due to misconfigurations of rooted Toons.

## script options

The script without option run a normal upgrade. It first check your current version and will ask you to which version you want to update.

With the option -v you can select a version number, ignoring any check if the version does exist and ignoring any required intermediate updates.

With the option -f you skip the entire update and do a fix local files only (patching important files on the Toon required for rooting which are overwritten with an upgrade).
