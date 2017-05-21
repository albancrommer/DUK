----------
Disclaimer: use at your own risks, yada yada yada.

----------


# What is DUKI? 

Need a Debian USB key that runs everywhere and keeps packages or files remain over reboots?  It's **exactly** what this project is all about! Lucky you! 


## Getting Started

### Crash course
```
git clone https://github.com/albancrommer/DUKI
cd DUKI
add-image.sh
burn-usb.sh
```
### Prerequisites

- An USB Key larger than 4GB
- A running Debian System with debootstrap installed, version >= Jessie(8)
- A sudo account. You might want to run as root, or use a NO-PASSWD account.


### Installing and running

**Fist, copy the code on your computer **

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


## Contributing

If you find any bug, got questions, feel like push requesting, please do. If you feel the feedback is bad, don't hesitate to push me on duki@albancrommer.com

## Versioning

Versioning is for the feeble! Seriously, this is Beta, no tests = no version.

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details

## Acknowledgments

* Thanks to @vincib https://github.com/vincib who did all the work, really :)
