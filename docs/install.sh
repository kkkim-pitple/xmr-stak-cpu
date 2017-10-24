#!/bin/bash
# MINER="kkredrabbit"
# OWNER="kk"
# SERVICE="ncloud"
# POOL="asia.cryptonight-hub.miningpoolhub.com:20580"
# RUN_TYPE="none" / shell / screen

MINER=$1
OWNER=$2
SERVICE=$3
POOL=$4
RUN_TYPE=$5
WORKER="$MINER.$OWNER-$SERVICE-$HOSTNAME"

# Install xmr
echo "[`date`] == Install xmr =="
sudo apt-get update
sudo apt-get install -y git libmicrohttpd-dev libssl-dev cmake build-essential libhwloc-dev

# Clone sources if not exist
echo "[`date`] == Clone Sources =="
if [ ! -d ~/xmr-stak-cpu ]; then 
    cd ~
    sudo git clone https://github.com/kkkim-pitple/xmr-stak-cpu.git
    cd ~/xmr-stak-cpu
    sudo cmake .
    sudo make install
fi

# Update Config.txt
echo "[`date`] == Update Config.txt =="
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
    ~/xmr-stak-cpu/bin/config.txt

# Update System Memory Config
echo "[`date`] == Update System Memory Config =="
LIMITS_CONF=/etc/security/limits.conf
grep -q -P "\*\tsoft\tmemlock\t262144" $LIMITS_CONF || sudo echo -e "*\tsoft\tmemlock\t262144" >> $LIMITS_CONF
grep -q -P "\*\thard\tmemlock\t262144" $LIMITS_CONF || sudo echo -e "*\thard\tmemlock\t262144" >> $LIMITS_CONF
#cat $LIMITS_CONF

# Update Update Enable HugePage
echo "[`date`] == Update Enable HugePage =="
HUGE_PAGE="vm.nr_hugepages=128"
HUGE_PAGE_CONF=/etc/sysctl.conf
grep -q $HUGE_PAGE $HUGE_PAGE_CONF || sudo echo -e "\n# HugePages\n$HUGE_PAGE" >> $HUGE_PAGE_CONF
#cat $HUGE_PAGE_CONF

sudo sysctl -w $HUGE_PAGE
sudo sysctl -p

# Done!
echo "[`date`] == Install Done! =="


# Run Mining
if [ $RUN_TYPE = "shell" ]
then
    echo "[`date`] == Run Mining : shell =="
    cd ~/xmr-stak-cpu/bin
    sudo ./xmr-stak-cpu
elif [ $RUN_TYPE = "screen" ]
then
    echo "[`date`] == Run Mining : screen =="
    cd ~/xmr-stak-cpu/bin
    screen sudo ./xmr-stak-cpu
fi

