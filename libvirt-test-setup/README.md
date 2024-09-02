# About

Libvirt definitions and cloud init isos that to run a small setup on one machine.

# Usage

## Step 0: Build the images

See root Readme.

## Step 1: Define the saarctf network

You need to enable ipv4 forwarding on the host.

WARNING: This adds an interface with a `10.32.250.0/24` subnet to your machine.
This is not entirely unlikely to cause conflicts with other networks you
are attached to. To reset your `default` libvirt network, apply the
`default-net.xml` file first.

```sh
virsh net-define libvirt-resources/saarctf-net.xml
```

## Step 2: Generate the seed isos

```sh
cd cloud-init
./genisos.sh
```

## Step 3: Prepare disks for the vms

```sh
virsh vol-clone --pool default vpn vpn-test
virsh vol-clone --pool default controller controller-test
virsh vol-clone --pool default checker checker-test
```

## Step 4: Define the VMs

```sh
virsh define libvirt-resources/checker.xml
virsh define libvirt-resources/controller.xml
virsh define libvirt-resources/vpn.xml
```

## Step 5: Start the VMs

```sh
virsh start checker-test
virsh start controller-test 
virsh start vpn-test
```
