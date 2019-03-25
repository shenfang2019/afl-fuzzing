#!/bin/bash

if [ ! -b "/dev/mmcblk1p3" ]; then
  echo "no /dev/mmcblk1p3 data partition, exit"
  exit
fi

offline_path="/sys/class/vhm/acrn_vhm"

# Check the device file of /dev/acrn_hsm to determine the offline_path
if [ -e "/dev/acrn_hsm" ]; then
offline_path="/sys/class/acrn/acrn_hsm"
fi
# offline SOS CPUs except BSP before launch UOS
for i in `ls -d /sys/devices/system/cpu/cpu[1-99]`; do
        online=`cat $i/online`
        idx=`echo $i | tr -cd "[1-99]"`
        echo cpu$idx online=$online
        if [ "$online" = "1" ]; then
                echo 0 > $i/online
		online=`cat $i/online`
		# during boot time, cpu hotplug may be disabled by pci_device_probe during a pci module insmod
		while [ "$online" = "1" ]; do
			sleep 1
			echo 0 > $i/online
			online=`cat $i/online`
		done
                echo $idx > ${offline_path}/offline_cpu
        fi
done

mkdir -p /data
mount /dev/mmcblk1p3 /data

mkdir -p ~/afl/in
mkdir -p ~/afl/out

AFL_NO_FORKSRV=1 AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1 ./afl-fuzz -i ~/afl/in -o ~/afl/out -m none -t 10000 \
	./acrn-dm --afl @@

umount /data
