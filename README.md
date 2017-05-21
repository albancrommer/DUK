# DUK

Need an USB key with Debian to run everywhere, with persistance, meaning installed packages and files will remain after reboot?  

That's what this project does! Lucky you! YAY!


## Getting Started

### Prerequisites

- An USB Key larger than 4GB
- A running Debian System with debootstrap installed, version >= Jessie(8)
- A sudo account. You might want to run as root, or use a NO-PASSWD account.

### Installing and running

Fist, copy the code on your computer 

```
git clone https://github.com/albancrommer/DUK
cd DUK
```

Then build a first image using

```
add-image.sh 
```

This will ask you for the name of your image, and will mostly take of the rest. Some questions will be asked to you, namely for languages or optional graphical interfaces.

If you're interested by the details (partitioning, etc.), technical details are below. 

Now we have a Debian Jessie image, we shall burn the key

```
burn-usb.sh 
```

The script will try to find your image and the USB key, and bake the former on the later for you.

Caution, USB keys can be slow, it can take a while.

Et voilà ! You should now have your USB key ready to boot !
