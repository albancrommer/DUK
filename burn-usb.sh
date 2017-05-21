#!/bin/bash -e
# là on a un système qui peut-être recopié tel quel sur une clé USB :

#
USB_DISK=""
#
APP_PATH=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
# 
cd $APP_PATH
#
declare -a IMAGE_LIST
for img in $( ls *img ); do IMAGE_LIST+=($img); done
case ${#IMAGE_LIST} in
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
		done
		read -p "Which image do you want to use [0,1,...]?" IMAGE_KEY
		IMAGE=${IMAGE_LIST[$IMAGE_KEY]}
		[ -z "$IMAGE" ] && { echo "Invalid key. Exiting."; exit 1; }
	;;
esac
IMAGE="${APP_PATH}/${IMAGE_LIST[0]}"

CHROOT="/mnt"
#
sudo dd if=${IMAGE} of=${IMAGE} & pid=$!
# 
ENDED=0
SIZE=$(stat -c %s $IMAGE)
while [ $ENDED -eq 0 ]; do
	#
	sleep 10;
	#
	kill -USR1 $pid; 
	echo "On $SIZE bytes"
	[ $? -ne 0 ] && ENDED=1
done
#
UUID_BOOT=$(uuidgen)
UUID_ROOT=$(uuidgen)
echo UUID BOOT $UUID_BOOT
echo UUID ROOT $UUID_ROOT
# 
PART_BOOT=$"{USB_DISK}1"
PART_ROOT=$"{USB_DISK}2"
sudo tune2fs "$PART_BOOT" -U $UUID_BOOT
sudo tune2fs "$PART_ROOT" -U $UUID_ROOT
#
sudo mount "$PART_ROOT" "$CHROOT"
sudo mount "$PART_BOOT" "$CHROOT"/boot
#
sudo bash -c "echo 'UUID=$UUID_BOOT /boot ext2 auto,noatime 0 0' > $CHROOT/etc/fstab"
sudo bash -c "echo 'UUID=$UUID_ROOT / ext4 auto,noatime 0 0' >> $CHROOT/etc/fstab"
#

for i in proc sys dev ; do mount /$i "$CHROOT"/$i --bind ; done
#
sudo chroot $CHROOT /mnt/update-grub2
#
sudo bash -c "echo '(hd0) $USB_DISK' > $CHROOT/boot/grub/device.map"
#
sudo chroot $CHROOT grub-install "$USB_DISK"
#
for i in proc sys dev ; do sudo umount "$CHROOT/$i" ; done
sudo umount "$CHROOT"/boot
sudo umount "$CHROOT"
exit
