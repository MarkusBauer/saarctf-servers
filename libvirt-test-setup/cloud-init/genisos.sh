#!/usr/bin/env sh
set -ex

for vm in vpn controller checker;
do
  cd $vm;
  ISO_PATH=/var/lib/libvirt/images/${vm}-seed.iso;
  genisoimage -output $ISO_PATH -volid cidata -joliet -rock user-data meta-data network-config;
  cd .. ;
done

