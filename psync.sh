#!/usr/bin/env /bin/bash

# Project sync tool
# Author: Matt Fiscus <m@fisc.us>

trap 'quit 1' 1 2 3 15

process="/tmp/psync.pid"
log="/tmp/psync.log"
config="/home/$USER/.psync/config.xml"
desktop="/home/$USER/.local/share/applications/psync.desktop"
icon="/home/$USER/.local/share/icons/psync.png"

# Create default configuration file on first run
if [ ! -f $config ]; then
  mkdir -p /home/$USER/.psync
  cat << EOF > $config
<?xml version="1.0"?>
<psync>
	<source>/home/$USER/Projects</source>
	<target>/var/www/html</target>
	<user>$USER</user>
	<server>remoteserver.domain.com</server>
	<frequency>10</frequency>
</psync>
EOF
fi

# Create application icon on first run
if [ ! -f $desktop ]; then
  mkdir -p /home/$USER/.local/share/applications
  cat << EOF > $desktop
[Desktop Entry]
Encoding=UTF-8
Name=Project Sync
Exec=psync.sh
Icon=psync.png
Categories=Application;Development;
Version=1.0
StartupNotify=true
Type=Application
Terminal=false
EOF
fi

# Download icon on first run
if [ ! -f $icon ]; then
  mkdir -p /home/$USER/.local/share/icons
  # Attempt to download icon from primary server (intranet)
  wget -q --output-document=$icon https://fisc.us/images/psync.png
  if [ $? != 0 ]; then
    # Attempt to download icon from secondary server (internet)
    wget -q --output-document=$icon https://fisc.us/images/psync.png
  fi
fi

if [ -f $process ]; then
  zenity --warning --title "Project Sync" --text "Process is already runnning"
  exit 1
else
  echo $$ > $process
fi

#function file_sync {
#  localfile=$1
#  remotefile=`echo $localfile | sed -e "s,$source,$target,"`
#  echo "`date +%m%d%y%H%M%S` - $localfile --> $remotefile" >> $log
#  rsync -azPq $localfile $user@$server:$remotefile
#}

# clean up files on quit
function quit {
  rm -f $process
  exit $1
}

# pull values from xml configuration file
function xml_query {
  xpath -q -e //$1 $config | sed -e "s,<$1>,," | sed -e "s,</$1>,,"
}

function ping_server {
  ping -c1 $1 >/dev/null 2>&1
  if [ $? != 0 ]; then
    zenity --warning --title "Project Sync" --text "Server is currently unreacheable"
    quit 1
  fi
}

# rsync source to target
function dir_sync {
  rsync -azPq --delete-after $source/ $user@$server:$target --exclude="logs" >/dev/null 2>&1
}

# read saved preferences from xml configuration file
source=`xml_query source`        # source directory
target=`xml_query target`        # target directory
user=`xml_query user`            # option alternate user for server
server=`xml_query server`        # optional server
frequency=`xml_query frequency`  # interval at which background process runs

ping_server $server

#frequency=`zenity --title "Project Sync" --window-icon=$icon --text "How often should sync run (seconds)?" --entry --entry-text=$frequency`
frequency=`zenity --title "Project Sync" --window-icon=$icon --text "How often should sync run (seconds)?" --scale --value=$frequency --min-value=1 --max-value=60 --step=1`
if [ $? = 0 ]; then
  # Frequency must not be less than 1
  if [[ $frequency -le 1 ]]; then
    frequency=1
    rate="second"
  else
    rate="seconds"
  fi
  exec 3> >(zenity --notification --listen --window-icon=$icon --text "Project Sync running every $frequency $rate")
  while [ -f $process ]; do
    #file=`find $source -type f -mmin -1 -print`
    #for x in $file; do
    #  file_sync $x
    #done
    dir_sync
    logger -t psync -- "background application running"
    sleep $frequency
  done
else
  quit 0
fi
