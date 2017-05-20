#!/bin/bash -e

read -p "Please give a name to your key (default is usbkey);" NAME
NAME=${NAME:-usbkey}

APP_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
IMAGE="${APP_PATH}/${NAME}.img"
CHROOT="${APP_PATH}/usbchroot"

#
truncate -s 4G "$IMAGE"
#
echo "
# partition table of usbkey.img
unit: sectors

    usbkey.img1 : start=     2048, size=   409600, Id=83
    usbkey.img2 : start=   411648, size=  7976960, Id=83
 "|sfdisk -f $IMAGE
#
LOOP_DEVICE=$(sudo losetup -P -f --show "$IMAGE")
#
PART_BOOT="${LOOP_DEVICE}p1"
PART_ROOT="${LOOP_DEVICE}p2"
# 
partprobe
#
sudo mkfs.ext2 "${PART_BOOT}"
sudo mkfs.ext4 "${PART_ROOT}"
# 
UUID_BOOT=$(uuidgen)
UUID_ROOT=$(uuidgen)
# 
sudo tune2fs "$PART_BOOT" -U $UUID_BOOT
sudo tune2fs "$PART_ROOT" -U $UUID_ROOT
#
[ ! -d "$CHROOT" ] || mkdir "$CHROOT"
[ ! -d "$CHROOT"/boot ] || mkdir "$CHROOT"/boot
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
sudo chroot $CHROOT apt-get -y install aptitude syslinux-common console-setup console-setup-linux keyboard-configuration locales
sudo chroot $CHROOT dpkg-reconfigure locales 
# et ceux utiles pour l'adminsys :
sudo chroot $CHROOT aptitude -y install cryptsetup mdadm lvm2 vim-nox emacs-nox mtr-tiny tcpdump strace ltrace openssl bridge-utils vlan screen rsync openssh-server
sudo chroot $CHROOT aptitude -y install -t jessie-backports linux-image-4.9.0-0.bpo.2-amd64 linux-base firmware-linux-free firmware-linux-nonfree
sudo chroot $CHROOT aptitude -y install smartmontools debootstrap debsums sudo 
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
sudo bash -c "echo '(hd0) $LOOP_DEVICE' > $CHROOT/grub/device.map"
#
sudo bash -c "echo 'UUID=$UUID / ext4 auto,noatime 0 0' > $CHROOT/etc/fstab"

#
sudo chroot "$CHROOT" grub-install $LOOP_DEVICE

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

for i in proc sys dev ; do sudo umount "$CHROOT/$i" ; done

exit




# là on a un système qui peut-être recopié tel quel sur une clé USB :
# par exemple sur une clé sur /dev/sdb
fdisk /dev/sdb
# créer une partition de 200M et une autre de ce que vous voulez (typiquement 1 à 2Go)
mkfs.ext4 /dev/sdb1
mkfs.ext4 /dev/sdb2
# on note leur UUID
tune2fs -l /dev/sdb2 | grep UUID
tune2fs -l /dev/sdb1 | grep UUID
# on monte et synchronise le contenu :
mount /dev/sdb2 /mnt
mkdir /mnt/boot
mount /dev/sdb1 /mnt/boot
sudo rsync "$CHROOT"/ /mnt/ -aPHSA --numeric-ids

for i in proc sys dev ; do mount /$i "$CHROOT"/$i --bind ; done
chroot /mnt
vi /etc/fstab
UUID=4d81b5a3-a877-4384-86a8-306041b7fb8f / ext4 auto,noatime 0 0
UUID=7b1e503a-0f82-4cd3-aa79-8c6a0c6557ef /boot ext4 auto,noatime 0 0
# bien entendu en remplaçant ces UUID par ceux obtenus via tune2fs pour sdb2 et sdb1

update-grub2
vi /boot/grub/device.map
(hd0) /dev/sdb

grub-install /dev/sdb
# là on a une clé USB bootable sur base d'UUIDs
