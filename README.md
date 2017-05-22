Disclaimer: use at your own risks, yada yada yada.

----------


# What is DUKI? 

Need a Debian USB key that runs everywhere and keeps packages or files over reboots? Damn, it's **exactly** what this is all about! Lucky you! 


## Getting Started

### Crash course
```
git clone https://github.com/albancrommer/DUKI
cd DUKI
./add-image.sh
./burn-usb.sh
```
### Prerequisites

- An USB Key larger than 4GB
- A sudo account. You might want to run as root, or use a NO-PASSWD account.
- A running Debian System with version >= Jessie(8)
- Installed packages on host : debootstrap, dcfldd 


### Installing and running

**Fist, copy the code on your computer**

```
git clone https://github.com/albancrommer/DUK
cd DUK
```

**Build a first image using:   ``` add-image.sh ```**

This will ask you for the name of your image, and will mostly take of the rest. Some questions will be asked to you, namely for languages or optional graphical interfaces.

If you're interested by the details (partitioning, etc.), technical details are below. 

**Burn the key using: ```burn-usb.sh ```**

The script will try to find your image and the USB key, and bake the former on the later for you.

Caution, USB keys can be slow, it can take a while.

Et voilà ! You should now have your USB key ready to boot !

There is something to do here, eventually: extend the main partition to your full USB key, create more partitions, etc. 

## Technical details

OK, so here are a few things about how it works

### Sparse file images

Every image you create will be a simple file, that looks like being 4GB but will effectively occupy less space, as they are "sparse" files. 

### Partitioned images

Every image has a basic partitionning : 

- part1 boot /boot ext2
- part2 root / ext4

During the image creation, these partitions are mounted as loop back, and the whole partition table gets copied to the USB device.

### GRUB2 bootloader

Every USB disk gets fresh UUIDs on their filesystems and a full GRUB2 installation

### dcfldd for device copy 

That's a nifty utilitary here: it does what dd would... except it does what everyone wants: show you the progress status!
```
sudo dcfldd if=usbkey.img of=/dev/sdb 
**113408 blocks (3544Mb) written.**
```
## Contributing

If you find any bug, got questions, feel like push requesting, please do. If you feel the feedback is bad, don't hesitate to push me on duki@albancrommer.com

## Versioning

Versioning is for the feeble! Seriously, this is Beta, no tests = no version.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Thanks to @vincib https://github.com/vincib who did all the work, really :)
