#!/bin/bash
# MINER="kkredrabbit"
# OWNER="kk"
# SERVICE="ncloud"
# POOL="asia.cryptonight-hub.miningpoolhub.com:20580"

# Install XMR
echo "[`date`] == Install XMR =="

MINER=$1
OWNER=$2
SERVICE=$3
POOL=$4
WORKER="$MINER.$OWNER-$SERVICE-$HOSTNAME"
XMR_DIR=/usr/local/xmr-stak-cpu

echo "MINER : $MINER"
echo "OWNER : $OWNER"
echo "SERVICE : $SERVICE"
echo "POOL : $POOL"
echo "WORKER : $WORKER"
echo "XMR_DIR : $XMR_DIR"

# apt update & install
echo "[`date`] == apt update & install =="
sudo apt-get update
sudo apt-get install -y git libmicrohttpd-dev libssl-dev cmake build-essential libhwloc-dev supervisor

# Clone sources if not exist
if [ ! -d $XMR_DIR ]; then
    echo "[`date`] == Clone Sources =="
    sudo git clone https://github.com/kkkim-pitple/xmr-stak-cpu.git $XMR_DIR
    cd $XMR_DIR
    sudo cmake .
    sudo make install
else
    echo "[`date`] == SKIP : Clone Sources =="
fi

# XMR Config.txt
echo "[`date`] == XMR Config.txt =="
#echo `lscpu | grep -v -i flags:`
SOCKETS=`lscpu | grep -i '^Socket(s):' | head -1 | awk '{ print $2 }'`
CORES_PER_SOCKET=`lscpu | grep -i '^Core(s) per socket:' | head -1 | awk '{ print $4 }'`
THREADS_PER_CORE=`lscpu | grep -i '^Thread(s) per core:' | head -1 | awk '{ print $4 }'`
CPUS=`lscpu | grep -i '^CPU(s):' | head -1 | awk '{ print $2 }'`
#echo $SOCKETS, $CORES_PER_SOCKET, $THREADS_PER_CORE, $CPUS
CPU_THREADS_CONF="[\n"
for (( i=0; i<$CPUS/$THREADS_PER_CORE; i++ ))
do
    CPU_THREADS_CONF+="\t{ \"low_power_mode\" : false, \"no_prefetch\" : true, \"affine_to_cpu\" : $(($i*$THREADS_PER_CORE)) },\n"
done
CPU_THREADS_CONF+="],\n"

sudo sed -i -r \
    -e "s/^null,/$CPU_THREADS_CONF/" \
    -e 's/^("pool_address" : ).*,/\1"'$POOL'",/' \
    -e 's/^("wallet_address" : ).*,/\1"'$WORKER'",/' \
    -e 's/^("pool_password" : ).*,/\1"x",/' \
    "$XMR_DIR/bin/config.txt"

# Update System Memory Config
echo "[`date`] == /etc/security/limits.conf =="
LIMITS_CONF=/etc/security/limits.conf
grep -q -P "\*\tsoft\tmemlock\t262144" $LIMITS_CONF || sudo echo -e "*\tsoft\tmemlock\t262144" >> $LIMITS_CONF
grep -q -P "\*\thard\tmemlock\t262144" $LIMITS_CONF || sudo echo -e "*\thard\tmemlock\t262144" >> $LIMITS_CONF
XMR_REBOOT_CHECK="# XMR REBOOT CHECK - DO NOT REMOVE"
XMR_REBOOT=$(grep -c "$XMR_REBOOT_CHECK" "$LIMITS_CONF")
if [ $XMR_REBOOT -eq 0 ]; then sudo echo -e $XMR_REBOOT_CHECK >> $LIMITS_CONF; fi
#cat $LIMITS_CONF

# Update Update Enable HugePage
echo "[`date`] == HugePage =="
HUGE_PAGE="vm.nr_hugepages=128"
HUGE_PAGE_CONF=/etc/sysctl.conf
grep -q $HUGE_PAGE $HUGE_PAGE_CONF || sudo echo -e "\n# HugePages\n$HUGE_PAGE" >> $HUGE_PAGE_CONF
#cat $HUGE_PAGE_CONF
sudo sysctl -w $HUGE_PAGE
sudo sysctl -p

# supervisor setting
#sudo systemctl start supervisor
#sudo systemctl enable supervisor 

SUPERVISOR_CONF=/etc/supervisor/conf.d/xmr-stak-cpu.conf
if [ ! -f $SUPERVISOR_CONF ]; then
    echo "[`date`] == supervisor setting =="
    sudo echo "[program:xmr-stak-cpu]" >> $SUPERVISOR_CONF
    sudo echo "command = $XMR_DIR/bin/xmr-stak-cpu" >> $SUPERVISOR_CONF
    sudo echo "directory = $XMR_DIR/bin" >> $SUPERVISOR_CONF
    sudo echo "autostart=true" >> $SUPERVISOR_CONF
    sudo echo "autorestart=true" >> $SUPERVISOR_CONF
    sudo echo "startretries=10" >> $SUPERVISOR_CONF
    sudo echo "redirect_stderr=true" >> $SUPERVISOR_CONF
    sudo supervisorctl update
else
    echo "[`date`] == SKIP : supervisor setting =="
fi

# Done!
echo "[`date`] == Install Done! =="

# Reboot if needed
if [ $XMR_REBOOT -eq 0 ]; then
    echo "[`date`] == reboot =="
    sudo reboot
fi
