#!/bin/bash
# LGSM update_check.sh function
# Author: Daniel Gibbs
# Website: http://gameservermanagers.com
lgsm_version="020216"

# Description: Checks if a server update is available.

local modulename="Update"
function_selfname="$(basename $(readlink -f "${BASH_SOURCE[0]}"))"

### SteamCMD Update Checker ###

fn_appmanifestinfo(){
	appmanifestfile=$(find "${filesdir}" -type f -name "appmanifest_${appid}.acf")
	appmanifestfilewc=$(find "${filesdir}" -type f -name "appmanifest_${appid}.acf"|wc -l)
}

fn_appmanifestcheck(){
fn_appmanifestinfo
# Multiple or no matching appmanifest files may sometimes be available.
# This is an error is corrected below if required.
if [ "${appmanifestfilewc}" -ge "2" ]; then
	sleep 1
	fn_printwarn "Multiple appmanifest_${appid}.acf files found"
	fn_scriptlog "Warning! Multiple appmanifest_${appid}.acf files found"
	sleep 2
	fn_printdots "Removing x${appmanifestfilewc} appmanifest_${appid}.acf files"
	sleep 1
	for appfile in ${appmanifestfile}; do
		rm "${appfile}"
	done
	appmanifestfilewc1="${appmanifestfilewc}"
	fn_appmanifestinfo
	if [ "${appmanifestfilewc}" -ge "2" ]; then
		fn_printfail "Unable to remove x${appmanifestfilewc} appmanifest_${appid}.acf files"
		fn_scriptlog "Failure! Unable to remove x${appmanifestfilewc} appmanifest_${appid}.acf files"
		sleep 1
		echo ""
		echo "	Check user permissions"
		for appfile in ${appmanifestfile}; do
			echo "	${appfile}"
		done
		exit 1
	else
		sleep 1
		fn_printok "Removed x${appmanifestfilewc1} appmanifest_${appid}.acf files"
		fn_scriptlog "Success! Removed x${appmanifestfilewc1} appmanifest_${appid}.acf files"
		sleep 1
		fn_printinfonl "Forcing update to correct issue"
		fn_scriptlog "Forcing update to correct issue"
		sleep 1
		update_dl.sh
		update_check.sh
	fi
elif [ "${appmanifestfilewc}" -eq "0" ]; then
	if [ "${forceupdate}" == "1" ]; then
		fn_printfail "Still no appmanifest_${appid}.acf found: Unable to update"
		fn_scriptlog "Warning! Still no appmanifest_${appid}.acf found: Unable to update"
		exit 1
	fi
	forceupdate=1
	fn_printwarn "No appmanifest_${appid}.acf found"
	fn_scriptlog "Warning! No appmanifest_${appid}.acf found"
	sleep 2
	fn_printinfonl "Forcing update to correct issue"
	fn_scriptlog "Forcing update to correct issue"
	sleep 1
	update_dl.sh
	update_check.sh
fi
}

fn_logupdaterequest(){
# Checks for server update requests from server logs.
fn_printdots "Checking for update: Server logs"
fn_scriptlog "Checking for update: Server logs"
sleep 1
requestrestart=$(grep -Ec "MasterRequestRestart" "${consolelog}")
if [ "${requestrestart}" -ge "1" ]; then
	fn_printoknl "Checking for update: Server logs: Update requested"
	sleep 1
	echo ""
	echo -ne "Applying update.\r"
	sleep 1
	echo -ne "Applying update..\r"
	sleep 1
	echo -ne "Applying update...\r"
	sleep 1
	echo -ne "\n"
	tmuxwc=$(tmux list-sessions 2>&1|awk '{print $1}'|grep -v failed|grep -Ec "^${servicename}:")
	if [ "${tmuxwc}" -eq 1 ]; then
		command_stop.sh
		update_dl.sh
		command_start.sh
	else
		update_dl.sh
	fi
else
	fn_printok "Checking for update: Server logs: No update requested"
	sleep 1
fi
}

fn_steamcmdcheck(){
fn_appmanifestcheck
# Checks for server update from SteamCMD
fn_printdots "Checking for update: SteamCMD"
fn_scriptlog "Checking for update: SteamCMD"
sleep 1

# Gets currentbuild
currentbuild=$(grep buildid "${appmanifestfile}" | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d\  -f3)

# Removes appinfo.vdf as a fix for not always getting up to date version info from SteamCMD

# Gets availablebuild info
cd "${rootdir}/steamcmd"
if [ -f "${HOME}/Steam/appcache/appinfo.vdf" ]; then
	rm -f "${HOME}/Steam/appcache/appinfo.vdf"
fi
availablebuild=$(./steamcmd.sh +login "${steamuser}" "${steampass}" +app_info_update 1 +app_info_print "${appid}" +app_info_print "${appid}" +quit | grep -EA 1000 "^\s+\"branches\"$" | grep -EA 5 "^\s+\"public\"$" | grep -m 1 -EB 10 "^\s+}$" | grep -E "^\s+\"buildid\"\s+" | tr '[:blank:]"' ' ' | tr -s ' ' | cut -d\  -f3)
if [ -z "${availablebuild}" ]; then
	fn_printfail "Checking for update: SteamCMD"
	fn_scriptlog "Failure! Checking for update: SteamCMD"
	sleep 1
	fn_printfailnl "Checking for update: SteamCMD: Not returning version info"
	fn_scriptlog "Failure! Checking for update: SteamCMD: Not returning version info"
	exit 1
else
	fn_printok "Checking for update: SteamCMD"
	fn_scriptlog "Success! Checking for update: SteamCMD"
	sleep 1
fi

if [ "${currentbuild}" != "${availablebuild}" ]; then
	echo -e "\n"
	echo -e "Update available:"
	sleep 1
	echo -e "	Current build: \e[0;31m${currentbuild}\e[0;39m"
	echo -e "	Available build: \e[0;32m${availablebuild}\e[0;39m"
	echo -e ""
	echo -e "	https://steamdb.info/app/${appid}/"
	sleep 1
	echo ""
	echo -en "Applying update.\r"
	sleep 1
	echo -en "Applying update..\r"
	sleep 1
	echo -en "Applying update...\r"
	sleep 1
	echo -en "\n"
	fn_scriptlog "Update available"
	fn_scriptlog "Current build: ${currentbuild}"
	fn_scriptlog "Available build: ${availablebuild}"
	fn_scriptlog "${currentbuild} > ${availablebuild}"

	tmuxwc=$(tmux list-sessions 2>&1|awk '{print $1}'|grep -v failed|grep -Ec "^${servicename}:")
	if [ "${tmuxwc}" -eq 1 ]; then
		command_stop.sh
		update_dl.sh
		command_start.sh
	else
		update_dl.sh
	fi
else
	echo -e "\n"
	echo -e "No update available:"
	echo -e "	Current version: \e[0;32m${currentbuild}\e[0;39m"
	echo -e "	Available version: \e[0;32m${availablebuild}\e[0;39m"
	echo -e "	https://steamdb.info/app/${appid}/"
	echo -e ""
	fn_printoknl "No update available"
	fn_scriptlog "Current build: ${currentbuild}"
	fn_scriptlog "Available build: ${availablebuild}"
fi
}

### END SteamCMD Update Checker ###

fn_teamspeak3_check(){
# Checks for server update from teamspeak.com using a mirror dl.4players.de
fn_printdots "Checking for update: teamspeak.com"
fn_scriptlog "Checking for update: teamspeak.com"
sleep 1

# Gets currentbuild info
# Checks currentbuild info is available, if fails a server restart will be forced to generate logs
if [ -z "$(find ./* -name 'ts3server*_0.log')" ]; then
	fn_printfail "Checking for update: teamspeak.com"
	sleep 1
	fn_printfailnl "Checking for update: teamspeak.com: No logs with server version found"
	fn_scriptlog "Failure! Checking for update: teamspeak.com: No logs with server version found"
	sleep 2
	fn_printinfonl "Checking for update: teamspeak.com: Forcing server restart"
	fn_scriptlog "Checking for update: teamspeak.com: Forcing server restart"
	sleep 2
	command_stop.sh
	command_start.sh
	sleep 2
	# If still failing will exit
	if [ -z "$(find ./* -name 'ts3server*_0.log')" ]; then
		fn_printfailnl "Checking for update: teamspeak.com: Still No logs with server version found"
		fn_scriptlog "Failure! Checking for update: teamspeak.com: Still No logs with server version found"
		exit 1
	fi
fi
currentbuild=$(cat $(find ./* -name 'ts3server*_0.log' 2> /dev/null | sort | egrep -E -v '${rootdir}/.ts3version' | tail -1) | egrep -o 'TeamSpeak 3 Server ((\.)?[0-9]{1,3}){1,3}\.[0-9]{1,3}' | egrep -o '((\.)?[0-9]{1,3}){1,3}\.[0-9]{1,3}')

# Gets the teamspeak server architecture
ts3arch=$(ls $(find ${filesdir}/ -name 'ts3server_*_*' 2> /dev/null | grep -v 'ts3server_minimal_runscript.sh' | sort | tail -1) | egrep -o '(amd64|x86)' | tail -1)

# Gets availablebuild info

# Grabs all version numbers not in correct order
wget "http://dl.4players.de/ts/releases/?C=M;O=D" -q -O -| grep -i dir | egrep -o '<a href=\".*\/\">.*\/<\/a>' | egrep -o '[0-9\.?]+'|uniq > .ts3_version_numbers_unsorted.tmp

# removes digits to allow sorting of numbers
 cat .ts3_version_numbers_unsorted.tmp | tr "." " " > .ts3_version_numbers_digit.tmp
# Sorts numbers in to correct order
# merges two files in to one with two columns sorts the numbers in to order then only outputs the second to the ts3_version_numbers.tmp
paste .ts3_version_numbers_digit.tmp .ts3_version_numbers_unsorted.tmp | awk '{print $1,$2,$3,$4 " " $0;}'| sort  -k1rn -k2rn -k3rn -k4rn | awk '{print $NF}' > .ts3_version_numbers.tmp

# Finds directory with most recent server version.
while read ts3_version_number; do
	wget --spider -q "http://dl.4players.de/ts/releases/${ts3_version_number}/teamspeak3-server_linux_${ts3arch}-${ts3_version_number}.tar.bz2"
	if [ $? -eq 0 ]; then
		availablebuild="${ts3_version_number}"
		# Break while-loop, if the latest release could be found
		break
	fi
done < .ts3_version_numbers.tmp
rm -f .ts3_version_numbers_digit.tmp
rm -f .ts3_version_numbers_unsorted.tmp
rm -f .ts3_version_numbers.tmp

# Checks availablebuild info is available
if [ -z "${availablebuild}" ]; then
	fn_printfail "Checking for update: teamspeak.com"
	fn_scriptlog "Checking for update: teamspeak.com"
	sleep 1
	fn_printfail "Checking for update: teamspeak.com: Not returning version info"
	fn_scriptlog "Failure! Checking for update: teamspeak.com: Not returning version info"
	sleep 2
	exit 1
else
	fn_printok "Checking for update: teamspeak.com"
	fn_scriptlog "Success! Checking for update: teamspeak.com"
	sleep 1
fi

# Removes dots so if can compare version numbers
currentbuilddigit=$(echo "${currentbuild}"|tr -cd '[:digit:]')
availablebuilddigit=$(echo "${availablebuild}"|tr -cd '[:digit:]')
if [ "${currentbuilddigit}" -ne "${availablebuilddigit}" ]; then
	echo -e "\n"
	echo -e "Update available:"
	sleep 1
	echo -e "	Current build: \e[0;31m${currentbuild} ${architecture}\e[0;39m"
	echo -e "	Available build: \e[0;32m${availablebuild} ${architecture}\e[0;39m"
	echo -e ""
	sleep 1
	echo ""
	echo -en "Applying update.\r"
	sleep 1
	echo -en "Applying update..\r"
	sleep 1
	echo -en "Applying update...\r"
	sleep 1
	echo -en "\n"
	fn_scriptlog "Update available"
	fn_scriptlog "Current build: ${currentbuild}"
	fn_scriptlog "Available build: ${availablebuild}"
	fn_scriptlog "${currentbuild} > ${availablebuild}"
	info_ts3status.sh
	if [ "${ts3status}" = "No server running (ts3server.pid is missing)" ]; then
		update_dl.sh
		command_start.sh
		sleep 5
		command_stop.sh
	else
		command_stop.sh
		update_dl.sh
		command_start.sh
	fi
else
	echo -e "\n"
	echo -e "No update available:"
	echo -e "	Current version: \e[0;32m${currentbuild}\e[0;39m"
	echo -e "	Available version: \e[0;32m${availablebuild}\e[0;39m"
	echo -e ""
	fn_printoknl "No update available"
	fn_scriptlog "Current build: ${currentbuild}"
	fn_scriptlog "Available build: ${availablebuild}"
fi
}

check.sh
fn_printdots "Checking for update"
if [ "${gamename}" == "Teamspeak 3" ]; then
	fn_teamspeak3_check
elif [ "${engine}" == "goldsource" ]||[ "${forceupdate}" == "1" ]; then
	# Goldsource servers bypass checks as fn_steamcmdcheck does not work for appid 90 servers.
	# forceupdate bypasses checks
	tmuxwc=$(tmux list-sessions 2>&1|awk '{print $1}'|grep -v failed|grep -Ec "^${servicename}:")
	if [ "${tmuxwc}" -eq 1 ]; then
		command_stop.sh
		update_dl.sh
		command_start.sh
	else
		update_dl.sh
	fi
else
	fn_logupdaterequest
	fn_steamcmdcheck
fi
