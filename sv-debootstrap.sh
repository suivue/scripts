#!/bin/bash
#
# Bootstrap a debian/ubuntu distribution
#
# debootstrap commands
# debootstrap --arch=amd64 SUITE TARGETDIR MIRROR
# SUITE: one of the Debian/Ubuntu release code names
#        e.g., bullseye, focal, impish etc
# MIRROR: package repository URL http://httpredir.debian.org/debian,
#         http://archive.ubuntu.com/ubuntu
# e.g.,  sudo debootstrap --arch=amd64 stretch \
#                /var/lib/container-example/example1 \
#                http://httpredir.debian.org/debian
#
# Following is based on instructions from Ubuntu MATE forums.
# Source: 
# https://ubuntu-mate.community/t/installing-ubuntu-mate-using-debootstrap/23780

printf "Enter distribution (code) name (e.g., bookworm, trixie, noble, questing etc.): "
read relname
#relname="trixie"

mkrawimg() {
        # Allocate space for the virtual disk

        if [ ! -d "$HOME/VirtualMachines" ]; then
                mkdir -p $HOME/VirtualMachines
        fi

        fallocate -l 16G $HOME/VirtualMachines/${relname}.raw
        
        # Create partitions.
        #
        (
                echo g    # create an empty gpt partition table (default is MBR)
                echo n    # new partition
                echo      # partition number (default 1)
                echo      # first sector
                echo +1G  # last sector; set 1G but, '+' prefix is required
                echo t    # change type of first partition
                echo 1    # change to 1 which is 'EFI System'
                echo n    # new partition for /
                echo      # partition number (default 2 now)
                echo      # first sector
                echo      # last sector; set all remaining space
                echo w    # write changes
        ) | fdisk $HOME/VirtualMachines/${relname}.raw
        
        # Create loop-devices using `kpartx`
        sudo kpartx -a -v $HOME/VirtualMachines/${relname}.raw 
#        losetup 
#        ls /dev/mapper/

        # Check the loop device number
        loopN=$(losetup | awk 'NR==2 {print $1}' | cut -d'/' -f3)
}

fmtrawimg() {
        sudo mkfs.vfat -F 32 -n EFI /dev/mapper/${loopN}p1
        sudo mkfs.ext4 -L System /dev/mapper/${loopN}p2
}

boot_strap() {
        # Create mount points for root and efi, usually under /mnt
        mp=/mnt/bootstrap-target
        sudo mkdir $mp
        sudo mount /dev/mapper/${loopN}p2 $mp/
        sudo mkdir -p $mp/boot/efi
        sudo mount /dev/mapper/${loopN}p1 $mp/boot/efi/
        
        # Run `debootstrap` command inside newly created file-system.
        sudo debootstrap --variant=minbase --arch=amd64 $relname $mp/
}

switch_root() {
        sudo mount --bind /dev $mp/dev
        sudo mount --bind /proc $mp/proc
        sudo mount --bind /sys $mp/sys
        sudo mount --bind /sys/firmware/efi/efivars $mp/sys/firmware/efi/efivars
        cat /etc/resolv.conf > $mp/etc/resolv.conf

        if [ ! -f "minstalldebu.sh" ]; then
                curl -fO https://raw.githubusercontent.com/suivue/scripts/refs/heads/main/minstalldebu.sh
        fi
        
        chmod +x minstalldebu.sh
        sudo mv minstalldebu.sh $mp/usr/local/bin/
        sudo chroot $mp bash -c 'minstalldebu.sh;bash'
}

cleanexit() {
       #sudo umount $mp/{dev,proc,sys} 
       sudo umount -R $mp
       sudo kpartx -d -v $HOME/VirtualMachines/${relname}.raw
}

mkrawimg
# Now call any function that needs root/sudo permission
# Install debootstrap if not installed
sudo apt-get -y install debootstrap kpartx qemu-kvm 
fmtrawimg
boot_strap
switch_root
cleanexit

