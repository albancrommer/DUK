#!/bin/bash -e
#
read -p "Please give a name to your key (default is usbkey);" NAME
NAME=${NAME:-usbkey}
#
APP_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
IMAGE="${APP_PATH}/${NAME}.img"
CHROOT="${APP_PATH}/usbchroot"
#
truncate -s 4G "$IMAGE"
# 
echo "
# partition table of usbkey.img
unit: sectors

    usbkey.img1 : start=     2048, size=   409600, Id=83, bootable
    usbkey.img2 : start=   411648, size=  7900000, Id=83
 "|sfdisk -f $IMAGE
#
LOOP_DEVICE=$(sudo losetup -P -f --show "$IMAGE")
#
PART_BOOT="${LOOP_DEVICE}p1"
PART_ROOT="${LOOP_DEVICE}p2"
# 
sudo partprobe
#
sudo mkfs.ext2 "${PART_BOOT}"
sudo mkfs.ext4 "${PART_ROOT}"
# 
UUID_BOOT=$(uuidgen)
UUID_ROOT=$(uuidgen)
echo UUID BOOT $UUID_BOOT
echo UUID ROOT $UUID_ROOT
# 
sudo tune2fs "$PART_BOOT" -U $UUID_BOOT
sudo tune2fs "$PART_ROOT" -U $UUID_ROOT
#
[ ! -d "$CHROOT" ] && mkdir "$CHROOT"
[ ! -d "$CHROOT"/boot ] && mkdir "$CHROOT"/boot
# 
sudo mount "$PART_ROOT" "$CHROOT"
# 
sudo debootstrap jessie "$CHROOT"
# 
sudo mount "$PART_BOOT" "$CHROOT"/boot
#
for i in proc sys dev ; do sudo mount /$i "${CHROOT}/$i" --bind ; done
# 
sudo bash -c "echo 'deb http://debian.octopuce.fr/debian/ jessie main contrib non-free                                                                         
deb http://debian.octopuce.fr/debian/ jessie-backports main contrib non-free
deb http://debian.octopuce.fr/debian-security jessie/updates main contrib non-free
' > ${CHROOT}/etc/apt/sources.list"
# 
sudo chroot $CHROOT apt-get update
# Une liste de packages nécessaire au bon fonctionnement du boot :
sudo chroot $CHROOT apt-get -y install aptitude grub2 console-setup console-setup-linux keyboard-configuration locales
sudo chroot $CHROOT dpkg-reconfigure locales 
# et ceux utiles pour l'adminsys :
sudo chroot $CHROOT aptitude -y install cryptsetup mdadm lvm2 vim-nox emacs-nox mtr-tiny tcpdump strace ltrace openssl bridge-utils vlan screen rsync openssh-server
sudo chroot $CHROOT aptitude -y install -t jessie-backports linux-image-4.9.0-0.bpo.2-amd64 linux-base firmware-linux-free firmware-linux-nonfree
sudo chroot $CHROOT aptitude -y install smartmontools debootstrap debsums sudo 
sudo chroot $CHROOT aptitude -y upgrade 
# CONFIGURATION TIME
# on enleve le script qui force de nouveaux ethXX à chaque nouveau boot
sudo chroot "$CHROOT"  rm /lib/udev/rules.d/75-persistent-net-generator.rules
#
sudo sed -i "1i\127.0.0.1       $NAME" "${CHROOT}/etc/hosts"
# 
sudo bash -c "echo '$NAME' > '${CHROOT}/etc/hostname'"
# 
sudo bash -c "echo '$NAME.example.com' > '${CHROOT}/etc/mailname'"
# 
sudo sed -i "2i\nameserver 8.8.8.8" "${CHROOT}/etc/resolv.conf"
#
sudo bash -c "echo 'UUID=$UUID_BOOT /boot ext2 auto,noatime 0 0' > $CHROOT/etc/fstab"
sudo bash -c "echo 'UUID=$UUID_ROOT / ext4 auto,noatime 0 0' >> $CHROOT/etc/fstab"
#
sudo dd if=${CHROOT}/usr/lib/SYSLINUX/mbr.bin of=${IMAGE} bs=440 count=1
# on fait du ménage :
sudo chroot "$CHROOT" apt-get clean
# on met un mdp à root
echo "Please set root password..."
sudo chroot $CHROOT passwd
# si besoin on crée un user
#sudo chroot $CHROOT adduser
# si on souhaite pouvoir se logguer root à distance :
# mettre "PermitRootLogin" à yes
sudo sed -i -r "s/^PermitRootLogin without-password/PermitRootLogin yes/" $CHROOT/etc/ssh/sshd_config

# on kill les trucs lancés dans le chroot :
sudo killall mdadm openssh-server
# 
for i in proc sys dev ; do sudo umount "$CHROOT/$i" ; done
sudo umount "$CHROOT"/boot
sudo umount "$CHROOT"
exit




