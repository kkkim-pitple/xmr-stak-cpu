#!/bin/bash

echo == Install xmr ==

# apt install
apt-get update
apt-get install -y git libmicrohttpd-dev libssl-dev cmake build-essential libhwloc-dev

# Clone sources if not exist
echo "== Clone Sources =="
if [ ! -d ~/xmr-stak-cpu ]; then 
    cd ~
    git clone https://github.com/kkkim-pitple/xmr-stak-cpu.git
    cd ~/xmr-stak-cpu
    cmake .
    make install
fi

# Update Config.txt
echo "== Update Config.txt =="
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

sed -i -r \
    -e "s/^null,/$CPU_THREADS_CONF/" \
    -e 's/^("pool_address" : ).*,/\1"asia.cryptonight-hub.miningpoolhub.com:20580",/' \
    -e 's/^("wallet_address" : ).*,/\1"kkredrabbit.xmr-'"${HOSTNAME}"'",/' \
    -e 's/^("pool_password" : ).*,/\1"x",/' \
    ~/xmr-stak-cpu/bin/config.txt

