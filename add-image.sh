#!/bin/bash
LOG_FILE=$(mktemp)
exec &> >(tee -a "$LOG_FILE")

# It should set a bunch of variables
APP_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
CHROOT=$(mktemp -d)

# It should load a bunch of functions
source "$APP_PATH/functions.sh"

# It should require sudo 
if ! which sudo &>/dev/null ; then 
	panic "You must install sudo."
fi

# It should require debootstrap
if ! which debootstrap &>/dev/null ; then 
	sudo apt-get install debootstrap
fi

# It should read an optional distribution name from parameters
[ -n "$1" ] && SUITE="$1"

# It should deploy a Jessie by default
SUITE=${SUITE:-jessie}
[ ! -f "/usr/share/debootstrap/scripts/$SUITE" ] && panic "Invalid suite requested: $SUITE"

# It should welcome the user 
info "<b>Hi and welcome to the Debian USB KEY Installer.</b>\n
Before installing the system, we will need to know more about the image you intend to create.
First we'll ask you for a name: please don't use spaces!
Then we'll need to know how big the non system partition, i.e. the standard usb key part will be."

# It should require an image name
NAME=$( input "Please give a name to your key (default is usbkey) " usbkey )
NAME=${NAME:-usbkey}

# It should set the image name
IMAGE="${APP_PATH}/${NAME}.img"

# It should escape if the image already exists 
[ -f "$IMAGE" ] && panic "The image '$IMAGE' already exists. Exiting"; 

# It should ask if the user wants more than 4Gb for the "usbstick" partition
if (question "Would you like to use more than 4Go for the Win/Mac partition?" ) then
    info "
<b>The game is to leave 4 Go FREE for the system on the total USB size.</b>\n
The 'USB stick' partition that will be readable on any non Linux system must account for these 4Go.\n 
For each standard USB key size, the correct USB stick size would then be TOTAL minus 4 Go, i.e.  \n
	 8 Go:   4\n
    16 Go:  12\n
    32 Go:  28\n
    64 Go:  60\n
   128 Go: 124\n
      "
    VFAT_GO=$(zenity --scale --text="Please provide the size in Go" --min-value="2" --max-value="252" --step="2"  --value=4)
    
    # Requested size should be an int > 1
    VFAT_CHECK=$(( $VFAT_GO + 1 )) &>/dev/null
    if [[ $? -ne 0 || $VFAT_CHECK -lt 2 ]]; then
		panic "Invalid value '$VFAT_GO'"
	fi
    
else 
	VFAT_GO=4
fi

VFAT_SECTOR_SIZE=$(( $VFAT_GO * 1024 * 1024 * 1024 / 512 ))
BOOT_SECTOR_START=$(( $VFAT_SECTOR_SIZE + 2048 ))
ROOT_SECTOR_START=$(( $BOOT_SECTOR_START + 409600 ))

# It should make a file image sparse  ie. seen as 4G but 0 blocks used at start
truncate -s $(( $VFAT_GO + 4 ))G "$IMAGE"

# It should partition the image with 2 partitions
echo "
# partition table of usbkey.img
unit: sectors

usbkey.img1 : start=     2048, size=  $VFAT_SECTOR_SIZE, Id= b
usbkey.img2 : start=  $BOOT_SECTOR_START, size=   409600, Id=83, bootable
usbkey.img3 : start=  $ROOT_SECTOR_START, size=  7976960, Id=83
usbkey.img4 : start=        0, size=        0, Id= 0
"|sfdisk -f $IMAGE

# It should mount the file as a loop back device
LOOP_DEVICE=$(sudo losetup -P -f --show "$IMAGE")
PART_VFAT="${LOOP_DEVICE}p1"
PART_BOOT="${LOOP_DEVICE}p2"
PART_ROOT="${LOOP_DEVICE}p3"

# It should fail if partitions not mounted
if [ ! -e $PART_ROOT ] || [ ! -e $PART_BOOT ] ; then 
	panic "Failed to mount the local loop partitions. Exiting."
fi

# It should make file systems for 2 partitions
sudo mkfs.vfat "${PART_VFAT}"
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
for i in proc sys dev ; do sudo mount /$i "${CHROOT}/$i" --rbind ; done

# It should force the jessie backport
sudo bash -c "echo 'deb http://httpredir.debian.org/debian jessie-backports main contrib non-free' >> $CHROOT/etc/apt/sources.list"

# It should install the right kernel 
if (question "Would you like to install a recent Linux Kernel (4.9/Jessie backports)?") ; then
	LINUX_IMAGE=" -t jessie-backports linux-image-4.9.0-0.bpo.2-amd64 "
else 
	LINUX_IMAGE=" linux-image-amd64 "
fi

# It should run an apt udate
sudo chroot $CHROOT apt-get update

# It should warn about dialogs
info "The package installation is about to begin.\n\n<b>Some dialogs are going to require your attention on the terminal.</b>\nYou will have to select the languages you want installed. For french, as an example, you must choose 'fr_FR.utf8'"

# It should install some basic packages 
sudo chroot $CHROOT apt-get -y install $LINUX_IMAGE locales aptitude linux-base firmware-linux-free firmware-linux-nonfree

# It should reconfigure the locales
sudo chroot $CHROOT dpkg-reconfigure locales 


if( question  "Would you like to install system admin packages?" ); then 
	# It should install packages necessary to adminsys
	sudo chroot $CHROOT apt-get -y install console-data keyboard-configuration console-setup-linux cryptsetup mdadm lvm2 vim-nox emacs-nox mtr-tiny tcpdump strace ltrace openssl bridge-utils vlan screen rsync openssh-server smartmontools debootstrap debsums sudo 

	# It should allow ssh remote root access
	sudo sed -i -r "s/^PermitRootLogin without-password/PermitRootLogin yes/" $CHROOT/etc/ssh/sshd_config
	
	# It should kill services starting by the chroot install
	pgrep mdadm &>/dev/null && sudo killall mdadm
	pgrep sshd &>/dev/null && sudo killall sshd

fi

if (question  "Would you like to run desktop, server, laptop package installs?"); then

	# It should run tasksel in the image
	sudo chroot $CHROOT apt-get -y install tasksel
	sudo chroot $CHROOT tasksel

fi

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

# It should install GRUB
sudo chroot $CHROOT env -i DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true PATH=/bin:/usr/bin:/sbin:/usr/sbin apt-get -y install initramfs-tools grub-pc  

# It should clean up apt
sudo chroot "$CHROOT" apt-get clean

# It should set root in new image
info "<b>CAUTION</b>\nNow the system is installed. You have to set the ROOT user password for it."
PASSWD=$(password "Root user's password");
sudo chroot $CHROOT bash -c "echo 'root:$PASSWD' | chpasswd"
echo $PASSWD > "$IMAGE.pass"
info "The password will be stored in clear into the file $IMAGE.pass"


# It should unmount
for i in proc sys dev ; do sudo umount -R "$CHROOT/$i" ; done
sudo umount "$CHROOT"/boot
sudo umount -R "$CHROOT"

rm -f $TMP_FILE

# Finish !
if( question  "OK, finished the $SUITE image. Do you want to burn an USB Key now?"); then 
	$APP_PATH/burn-usb.sh $IMAGE
fi
 



