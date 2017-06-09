#!/bin/bash
LOG_FILE=$(mktemp)
exec &> >(tee -a "$LOG_FILE")

# This is where we will chroot 
CHROOT="/mnt"

# It should get the script absolute path, and then chdir
APP_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "$APP_PATH"

# It should load a bunch of functions
source "$APP_PATH/functions.sh"

# It should accept an image path param
if [ -n "$1" ] ; then 
	[ ! -f "$1" ] && panic "Invalid image '$1' provided"
	PARAM_IMAGE="$1"
fi

# It should require dcfldd on host
which dcfldd &>/dev/null || sudo apt-get install dcfldd

# It should search for non mounted disks / devices
declare -a DEVICE_LIST
for device in $( ls /dev/sd? ); do 
	if mount | grep -q "$device"; then 
		echo "[!] $device is mounted, skipping."
		continue
	fi
	DEVICE_LIST+=($device); 
done

# It should choose a usb disk, eventually by asking the user
case ${#DEVICE_LIST[@]} in
	(0)
		panic "No usable disk found. Unmount the USB key if necessary. Exiting."; 
	;;
	(1) 
		USB_DISK="${DEVICE_LIST[0]}"
	;;
	(*)
		PICK_LIST=()
		MSG="Found disks:\n"
		for key in ${!DEVICE_LIST[@]}; do 
			DEVICE_NAME=${DEVICE_LIST[$key]}
			PICK_LIST+=("$key $DEVICE_NAME")
			MSG="$MSG\n─────────────────────────────────────────────────\n<b>$DEVICE_NAME</b>"
			# It should use udevadm if available to show usb info and model
			if which udevadm &>/dev/null ; then 
				MSG="$MSG\n"$(udevadm info -a $DEVICE_NAME|egrep -i 'DRIVERS=="usb-storage"|ATTRS{model}'|sed -r 's/^.*=="(.*)".*?/\1/') 
			fi
			# It should print the block size
			DEVICE_SIZE=$(sudo blockdev --getsize64 $DEVICE_NAME)
			MSG="$MSG\n"$(( $DEVICE_SIZE / ( 1024 * 1024 * 1024 ) + 1 ))"Go"
		done
		info "$MSG"
		USB_DISK=$(zenity --list --radiolist --column=Pick --column=Image ${PICK_LIST[@]} 2>/dev/null)
		[ -z "$USB_DISK" ] && panic "Invalid choice. Exiting."; 
	;;
esac

# It should find an image to be burned
declare -a IMAGE_LIST

# It should select the image requested as param
if [ -n "$PARAM_IMAGE" ]; then 
	IMAGE_LIST+=($PARAM_IMAGE)
else 
# It should search for images
	for img in $( ls *img ); do IMAGE_LIST+=($img); done
fi
case ${#IMAGE_LIST[@]} in
	(0)
		panic "No file 'XXX.img' found in $APP_PATH"; 
	;;
	(1) 
		IMAGE="$( basename ${IMAGE_LIST[0]} )"
	;;
	(*)
		PICK_LIST=()
		for key in ${!IMAGE_LIST[@]}; do 
			PICK_LIST+=("$key ${IMAGE_LIST[$key]}")
		done
		IMAGE=$(zenity --list --title "Image Selection" --text "Please choose an image to burn" --radiolist --column=Pick --column=Image ${PICK_LIST[@]} 2>/dev/null)
		[ -z "$IMAGE" ] && panic "No image selected. Exiting."; 
	;;
esac
IMAGE="${APP_PATH}/$IMAGE"
[ -f "$IMAGE"] && panic "Invalid image $IMAGE requested"

# It should print the command and validate
if( ! question "Please validate the following informations: 
\nSource image:
\n<b>$IMAGE</b>
\nDestination:
\n<b>$USB_DISK</b>" ) ; then 
	exit
fi

# It should burn the image on the disk
sudo dcfldd if=${IMAGE} of=${USB_DISK} 

# It should find the new partitions
sudo partprobe "$USB_DISK"

# It should define new UUIDs
UUID_BOOT=$(uuidgen)
UUID_ROOT=$(uuidgen)
echo UUID BOOT $UUID_BOOT
echo UUID ROOT $UUID_ROOT

# It should apply new UUIDs to the newly burned devices
PART_VFAT="${USB_DISK}1"
PART_BOOT="${USB_DISK}2"
PART_ROOT="${USB_DISK}3"
sudo tune2fs "$PART_BOOT" -U $UUID_BOOT
sudo tune2fs "$PART_ROOT" -U $UUID_ROOT

# It should mount the partitions
sudo mount "$PART_ROOT" "$CHROOT"
sudo mount "$PART_BOOT" "$CHROOT"/boot

# It should set the new UUID to the fstab
sudo bash -c "echo '# <file system> <mount point>   <type>  <options>       <dump>  <pass>' > $CHROOT/etc/fstab"
sudo bash -c "echo 'UUID=$UUID_BOOT /boot ext2 defaults 0 2' >> $CHROOT/etc/fstab"
sudo bash -c "echo 'UUID=$UUID_ROOT / ext4 errors=remount-ro 0 1' >> $CHROOT/etc/fstab"

# It should mount dev sys proc in the chroot
for i in proc sys dev ; do sudo mount --rbind /$i "$CHROOT"/$i  ; done

# It should run update grub in the chroot
sudo chroot $CHROOT update-grub2

# It should reconfigure initramfs
sudo chroot $CHROOT dpkg-reconfigure initramfs-tools

# It should set the device map for grup
sudo bash -c "echo '(hd0) $USB_DISK' > $CHROOT/boot/grub/device.map"

# It should install grub on the USB KEY
sudo chroot $CHROOT grub-install "$USB_DISK"

exit
# It should unmount
for i in proc sys dev ; do sudo umount -R "$CHROOT/$i" ; done
sudo umount "$CHROOT"/boot
sudo umount "$CHROOT"

# It should eventually resize the Root FS 
if ( question "Would you like to automatically resize the system partition?" ); then

	
	# It should get the start sector
	USB_DISK_NAME=$(basename ${USB_DISK})
	START_SECTOR=$( cat /sys/block/$USB_DISK_NAME/${USB_DISK_NAME}3/start )

	# It should resize the root partition
	sudo fdisk ${USB_DISK} <<EOF
d
3
n
p
3
$START_SECTOR

w
EOF

	# It should resize the root fs
	sudo resize2fs -f "$PART_ROOT"

fi

# It should check the filesystems 
sudo fsck.vfat -a "$PART_VFAT"
sudo fsck.ext4 -a "$PART_BOOT"
sudo fsck.ext4 -a "$PART_BOOT"

# @todo label the partitions
# aptitude install mtools
# sudo mlabel -i /dev/sdb1 -s ::
# sudo e2label /dev/sdb2 usb_boot
# sudo e2label /dev/sdb3 usb_root


# It should finish
info "OK, your USB key is ready"
