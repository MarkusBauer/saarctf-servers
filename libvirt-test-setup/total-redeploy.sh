#!/usr/bin/env sh

set -ex

cd ..

virsh destroy checker-test
virsh destroy controller-test
virsh destroy vpn-test

virsh vol-delete --pool default checker-test
virsh vol-delete --pool default controller-test
virsh vol-delete --pool default vpn-test

virsh vol-delete --pool default checker
virsh vol-delete --pool default controller
virsh vol-delete --pool default vpn

packer build -var-file global-variables.pkrvars.hcl controller
packer build -var-file global-variables.pkrvars.hcl vpn
packer build -var-file global-variables.pkrvars.hcl checker

virsh vol-clone --pool default checker checker-test
virsh vol-clone --pool default controller controller-test
virsh vol-clone --pool default vpn vpn-test

virsh start checker-test
virsh start controller-test
virsh start vpn-test
