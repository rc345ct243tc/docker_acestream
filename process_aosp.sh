#!/bin/bash

if [ ! -f $2/system.img ]; then
	unzip -j $1 IMAGES/system.img -d $2
fi

if [ ! -f $2/apex_payload.img ]; then
	unzip -j $1 SYSTEM/apex/com.android.runtime.apex -d $2
	unzip -j $2/com.android.runtime.apex apex_payload.img -d $2
	rm $2/com.android.runtime.apex
fi

mkdir -p $2/system_mount
sudo mount -o loop,ro $2/system.img $2/system_mount

mkdir -p $2/apex_mount
sudo mount -o loop,ro $2/apex_payload.img $2/apex_mount

mkdir -p $2/system
mkdir -p $2/system/bin
for file in netstat ping sh toolbox toybox; do
	sudo cp $2/system_mount/system/bin/$file $2/system/bin
done
mkdir -p $2/system/lib
for file in libbase.so libc++.so libcrypto.so libcutils.so liblog.so libprotobuf-cpp-lite.so libselinux.so libssl.so libstdc++.so libutils.so libz.so; do
	sudo cp $2/system_mount/system/lib64/$file $2/system/lib
done
mkdir -p $2/system/sbin
sudo cp $2/system_mount/system/bin/ifconfig $2/system/sbin

sudo cp $2/apex_mount/bin/linker $2/system/bin
sudo cp $2/apex_mount/bin/linker64 $2/system/bin
for file in libc.so libdl.so libm.so; do
	sudo cp $2/apex_mount/lib64/bionic/$file $2/system/lib
done

sudo chown -R 1000:1000 $2/system

sudo umount $2/system_mount
sudo umount $2/apex_mount
rm -rf $2/system_mount
rm -rf $2/apex_mount
