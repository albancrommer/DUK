#!/bin/bash -e

# This is where we will chroot 
CHROOT="/mnt"

# It should get the script absolute path, and then chdir
APP_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
cd "$APP_PATH"

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
		echo "No usable disk found. Unmount the USB key if necessary. Exiting."; 
		exit 1; 
	;;
	(1) 
		USB_DISK="${DEVICE_LIST[0]}"
	;;
	(*)
		echo "Found disks:"
		for key in ${!DEVICE_LIST[@]}; do 
			echo " * $key: ${DEVICE_LIST[$key]}"
			# It should udevadm if available to show usb info and model
			if which udevadm &>/dev/null ; then 
				udevadm info -a ${DEVICE_LIST[$key]}|egrep -i 'DRIVERS=="usb-storage"|ATTRS{model}'|sed -r 's/^.*=="(.*)".*?/\1/'; 
			fi
		done
		read -p "Which disk do you want to use [0,1,...]?" DEVICE_KEY
		USB_DISK=${DEVICE_LIST[$DEVICE_KEY]}
		[ -z "$USB_DISK" ] && { echo "Invalid choice. Exiting."; exit 1; }
	;;
esac

# It should find an image to be burned
declare -a IMAGE_LIST
for img in $( ls *img ); do IMAGE_LIST+=($img); done
case ${#IMAGE_LIST[@]} in
	(0)
		echo "No file 'XXX.img' found in $APP_PATH"; 
		exit 1; 
	;;
	(1) 
		IMAGE="${IMAGE_LIST[0]}"
	;;
	(*)
		echo "Found images:"
		for key in ${!IMAGE_LIST[@]}; do 
			echo " * $key: ${IMAGE_LIST[$key]}"
		done
		read -p "Which image number do you want to use [0,1,...]?" IMAGE_KEY
		IMAGE=${IMAGE_LIST[$IMAGE_KEY]}
		[ -z "$IMAGE" ] && { echo "Invalid key. Exiting."; exit 1; }
	;;
esac
IMAGE="${APP_PATH}/$IMAGE"

# It should print the command and validate
read -n 1 -p "Ready to burn '$USB_DISK' with image '$IMAGE'. OK? [Y/n] " REPLY
REPLY=${REPLY:-Y}
[ "${REPLY^^}" != "Y" ] && { echo "OK, exiting."; exit 1; }

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
for i in proc sys dev ; do sudo mount /$i "$CHROOT"/$i --bind ; done


# It should run update grub in the chroot
sudo chroot $CHROOT update-grub2

# It should set the device map for grup
sudo bash -c "echo '(hd0) $USB_DISK' > $CHROOT/boot/grub/device.map"

# It should install grub on the USB KEY
sudo chroot $CHROOT grub-install "$USB_DISK"

# It should unmount
for i in proc sys dev ; do sudo umount "$CHROOT/$i" ; done
sudo umount "$CHROOT"/boot
sudo umount "$CHROOT"

# It should resize the root partition
sudo fdisk ${USB_DISK} <<EOF
d
3
n
p
3
8800256

w
EOF
# It should resize the root fs
sudo resize2fs -f "$PART_ROOT"
