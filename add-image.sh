#!/bin/bash

# It should read an optional distribution name from parameters
[ -n "$1" ] && SUITE="$1"

# It should deploy a Jessie by default
SUITE=${SUITE:-jessie}
[ ! -f "/usr/share/debootstrap/scripts/$SUITE" ] && { echo "Invalid suite requested: $SUITE"; exit 1; }

# It should require an image name
read -p "Please give a name to your key (default is usbkey): " NAME
NAME=${NAME:-usbkey}

# It should set a bunch of variables
APP_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
IMAGE="${APP_PATH}/${NAME}.img"
CHROOT="${APP_PATH}/usbchroot"

# It should escape if the image already exists 
[ -f "$IMAGE" ] && { echo "The image '$IMAGE' already exists. Exiting"; exit 1; }

# It should make a file image sparse  ie. seen as 4G but 0 blocks used at start
truncate -s 4G "$IMAGE"

# It should partition the image with 2 partitions
echo "
# partition table of usbkey.img
unit: sectors

usbkey.img1 : start=     2048, size=  8388608, Id= b
usbkey.img2 : start=  8390656, size=   409600, Id=83, bootable
usbkey.img3 : start=  8800256, size=  7976960, Id=83
usbkey.img4 : start=        0, size=        0, Id= 0
"|sfdisk -f $IMAGE

# It should mount the file as a loop back device
LOOP_DEVICE=$(sudo losetup -P -f --show "$IMAGE")
PART_VFAT="${LOOP_DEVICE}p1"
PART_BOOT="${LOOP_DEVICE}p2"
PART_ROOT="${LOOP_DEVICE}p3"

# It should make file systems for 2 partitions
sudo mkfs.vfat "${PART_FAT}"
sudo mkfs.ext2 "${PART_BOOT}"
sudo mkfs.ext4 "${PART_ROOT}"

# It should create the chroot dirs if necessary
[ ! -d "$CHROOT" ] && mkdir "$CHROOT"
[ ! -d "$CHROOT"/boot ] && mkdir "$CHROOT"/boot

# It should mount the root partition
sudo mount "$PART_ROOT" "$CHROOT"

# It should run debootstrap
sudo debootstrap $SUITE "$CHROOT"

# It should mount the boot partition
sudo mount "$PART_BOOT" "$CHROOT"/boot

# It should mount proc sys dev for the chroot
for i in proc sys dev ; do sudo mount /$i "${CHROOT}/$i" --bind ; done

# It should run an apt udate
sudo chroot $CHROOT apt-get update

# It should install packages necessary to booting
sudo chroot $CHROOT apt-get -y install aptitude grub2 console-setup console-setup-linux keyboard-configuration locales

# It should reconfigure the locales
sudo chroot $CHROOT dpkg-reconfigure locales 

# It should reconfigure the console-setup
sudo chroot $CHROOT dpkg-reconfigure console-setup 

# It should install
sudo chroot $CHROOT aptitude -y install -t jessie-backports linux-image-4.9.0-0.bpo.2-amd64 linux-base firmware-linux-free firmware-linux-nonfree

# It should install packages necessary to adminsys
sudo chroot $CHROOT aptitude -y install cryptsetup mdadm lvm2 vim-nox emacs-nox mtr-tiny tcpdump strace ltrace openssl bridge-utils vlan screen rsync openssh-server install smartmontools debootstrap debsums sudo 

# It should run tasksel in the image
sudo chroot $CHROOT tasksel

# It should force an upgrade
sudo chroot $CHROOT aptitude -y upgrade 

# It should remove the old interfaces
sudo chroot "$CHROOT"  rm /lib/udev/rules.d/75-persistent-net-generator.rules

# It should set the host name 
sudo sed -i "1i\127.0.0.1       $NAME" "${CHROOT}/etc/hosts"
sudo bash -c "echo '$NAME' > '${CHROOT}/etc/hostname'"
sudo bash -c "echo '$NAME.example.com' > '${CHROOT}/etc/mailname'"

# It should add a default resolver 
sudo sed -i "2i\nameserver 8.8.8.8" "${CHROOT}/etc/resolv.conf"

# It should set the UUIDs in the fstab
sudo bash -c "echo 'UUID=$UUID_BOOT /boot ext2 auto,noatime 0 0' > $CHROOT/etc/fstab"
sudo bash -c "echo 'UUID=$UUID_ROOT / ext4 auto,noatime 0 0' >> $CHROOT/etc/fstab"

# It should clean up apt
sudo chroot "$CHROOT" apt-get clean

# It should set root in new image
echo "CAUTION! We're about to set root password. Please remember what you set :)"
sudo chroot $CHROOT passwd

# It should allow remote root access
sudo sed -i -r "s/^PermitRootLogin without-password/PermitRootLogin yes/" $CHROOT/etc/ssh/sshd_config

# It should kill services starting by the chroot install
sudo killall mdadm openssh-server

# It should unmount
for i in proc sys dev ; do sudo umount "$CHROOT/$i" ; done
sudo umount "$CHROOT"/boot
sudo umount "$CHROOT"

# Finish !
echo "OK. finished. Now you can run burn-usb.sh!"
 



