#! /bin/sh
#

distroname="trixie"

# Allocate space for the virtual disk
#fallocate -l 16G $HOME/VirtualMachines/${distroname}.raw
fallocate -l 16G ${distroname}.raw

# Create partitions.
# Below is `fdisk` automated method suitable for scripts
#
(
        echo g    # create an empty gpt partition table (default is MBR)
        echo n    # new partition
        echo      # partition number (default 1) 
        echo      # first sector
        echo +1G  # last sector, set 1G but, '+' prefix is required
        echo t    # change type of first partition
        echo 1    # change to 1 which is 'EFI System'
        echo n    # new partition for /
        echo      # partition number (default 2 now)
        echo      # first sector
        echo      # last sector; set all remaining space
        echo w    # write changes
) | fdisk ${distroname}.raw

# Create loop-devices using `kpartx`
sudo kpartx -a -v ${distroname}.raw 

# Confirm using `losetup` and checking '/dev/mapper' directory
losetup 
ls /dev/mapper/
