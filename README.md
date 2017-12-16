# cross-rpi-kernel

A Docker image for cross-compiling Linux kernel for Raspberry Pi and a build
script for it.


## Example use

```
$ git clone git@github.com:Idein/linux.git --branch rpi-4.9.y-vc4mem
$ git clone git@github.com:Terminus-IMRC/cross-rpi-kernel.git
$ cd linux/
$ ../cross-rpi-kernel/build_kernel.sh -v 2 -t bcm2709_defconfig    # Load default config
$ ../cross-rpi-kernel/build_kernel.sh -v 2    # Build and install to dest-rpi2/
$ rsync --rsync-path='sudo rsync' -r dest-rpi2/ pi@remote:/    # Transfer to remote Pi
```
