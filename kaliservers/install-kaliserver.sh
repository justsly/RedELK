#!/bin/sh
#
# Part of RedELK
# Script to install RedELK on Cobalt Strike teamservers
#
# Author: Outflank B.V. / Marc Smeets / @mramsmeets
#
# License : BSD3
#
# Version: 0.8
#

LOGFILE="redelk-install.log"
INSTALLER="RedELK kaliserver installer"
TIMEZONE="Europe/Berlin"
CHECKFILEBEATINSTALLED=true # set to false to skip the check for already insatlled filebeats. Warning, only do this if you are really sure your installed filebeat version works OK with your ELK stack version on the elkserver

echoerror() {
    printf "`date +'%b %e %R'` $INSTALLER - ${RC} * ERROR ${EC}: $@\n" >> $LOGFILE 2>&1
}

echo "This script will install and configure necessary components for RedELK on Cobalt Strike teamservers"

if ! [ $# -eq 3 ] ; then
    echo "[X] ERROR Incorrect amount of parameters"
    echo "[X] require 1st parameter: identifier of this machine to set in filebeat config."
    echo "[X] require 2nd parameter: attackscenario name."
    echo "[X] require 3rd parameter: IP/DNS:port where to ship logs to."
    echoerror "Incorrect amount of parameters"
    exit 1
fi

if [ "$CHECKFILEBEATINSTALLED" = "true" ]; then
    echo "Checking if filebeat is already installed"
    dpkg -s filebeat | grep Status >> $LOGFILE 2>&1
    ERROR=$?
    if [ $ERROR -eq 0 ] ; then
        echoerror "Filebeat already installed. Quiting (Error Code: $ERROR)."
        echo "[X] Filebeat already installed."
        echo " Please check manually if the installed version equals what your ELK server expects." 
        echo " Quiting."
    fi
fi

echo "Setting timezone"
timedatectl set-timezone $TIMEZONE >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not set timezone (Error Code: $ERROR)."
fi

echo "Restarting rsyslog deamon for new timezone to take effect"
service rsyslog restart >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not restart rsyslog deamon (Error Code: $ERROR)."
fi

echo "Adding GPG key of Elastic"
wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add - >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not add GPG key (Error Code: $ERROR)."
fi

echo "Installing apt-transport-https"
apt-get install -y apt-transport-https >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not install apt-transport-https (Error Code: $ERROR)."
fi

echo "Adding Elastic APT repository"
if [ ! -f  /etc/apt/sources.list.d/elastic-6.x.list ]; then
    echo "deb https://artifacts.elastic.co/packages/6.x/apt stable main" | tee -a /etc/apt/sources.list.d/elastic-6.x.list >> $LOGFILE 2>&1
fi
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not add APT repository (Error Code: $ERROR)."
fi

echo "Updating APT"
apt-get update  >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not update APT (Error Code: $ERROR)."
fi

echo "Installing filebeat ..."
apt-get install -y filebeat >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not install filebeat (Error Code: $ERROR)."
fi

echo "Setting filebat to auto start after reboot"
update-rc.d filebeat defaults 95 10 >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not change auto boot settings (Error Code: $ERROR)."
fi

echo "Making backup of original filebeat config"
mv /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.ori >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not make backup (Error Code: $ERROR)."
fi

echo "Copying new config file"
cp ./filebeat/filebeat.yml /etc/filebeat/ >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not copy filebeat config (Error Code: $ERROR)."
fi

echo "Copying ca file "
cp ./filebeat/redelkCA.crt /etc/filebeat/ >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not copy ca file (Error Code: $ERROR)."
fi

echo "Altering hostname field in filebeat config"
sed -i s/'@@HOSTNAME@@'/$1/g /etc/filebeat/filebeat.yml  >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not change hostname field in filebeat config (Error Code: $ERROR)."
fi

echo "Altering attackscenario field in filebeat config "
sed -i s/'@@ATTACKSCENARIO@@'/$2/g /etc/filebeat/filebeat.yml >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not change attackscenario field in filebeat config (Error Code: $ERROR)."
fi

echo "Altering log destination field in filebeat config "
sed -i s/'@@HOSTANDPORT@@'/$3/g /etc/filebeat/filebeat.yml >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not change log destination field in filebeat config (Error Code: $ERROR)."
fi

echo "Starting filebeat"
service filebeat start >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not start filebeat (Error Code: $ERROR)."
fi

echo "Creating scponly user"
grep scponly /etc/passwd > /dev/null
EXIT=$?
if [ $EXIT -ne 0  ]; then
    useradd -m -p $(openssl passwd -1 `head /dev/urandom | tr -dc A-Za-z0-9 | head -c20`) scponly
else
    echo "User scponly already exists"
fi  >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not create scponly user (Error Code: $ERROR)."
fi

echo "Setting ssh key authentication for scponly user"
grep scponly /etc/passwd > /dev/null
EXIT=$?
if [ $EXIT -eq 0  ]; then
    mkdir -p /home/scponly/.ssh && cat ./ssh/id_rsa.pub >> /home/scponly/.ssh/authorized_keys && chown -R scponly /home/scponly/.ssh && chmod 700 /home/scponly/.ssh 
fi  >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not set ssh key authentication for scponly user (Error Code: $ERROR)."
fi

echo "Installing rssh"
apt-get install -y rssh >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not install rssh (Error Code: $ERROR)."
fi

echo "Configuring rssh"
grep scponly /etc/rssh.conf > /dev/null
EXIT=$?
if [ $EXIT -ne 0 ]; then
    cat << 'EOF' >> /etc/rssh.conf 
allowscp
allowsftp
allowrsync
user = scponly:011:100110:
EOF
fi >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not configure rssh (Error Code: $ERROR)."
fi

echo "Creating crontab for local rscync of kali logs"
cp ./cron.d/redelk /etc/cron.d/redelk >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not create crontab for local rsync of cobaltstrike logs (Error Code: $ERROR)."
fi

echo "Creating log directories"
mkdir -p /opt/Empire/logs >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not create logfolder (Error Code: $ERROR)."
fi

echo "Copying SQL queries"
cp -r sql_query /opt/Empire/ >> $LOGFILE 2>&1
ERROR=$?
if [ $ERROR -ne 0 ]; then
    echoerror "Could not copy SQL query folder (Error Code: $ERROR)."
fi



echo ""
echo ""
echo "Done with setup of RedELK on teamserver."
echo ""

