#!/bin/bash
#
# Bootstrap a debian/ubuntu distribution
#
# Following is based on instructions from Ubuntu MATE forums.
# Source:
# https://ubuntu-mate.community/t/installing-ubuntu-mate-using-debootstrap/23780

PS3="Select a base: "
select base in debian ubuntu
do
		read -p "Enter release name (e.g., bookworm, trixie, noble, questing etc.): " relname
        case $base in
                "debian")
                        if [ -f "/usr/share/keyrings/debian-archive-keyring.gpg" ]; then
                                if [ ! -e "/usr/share/debootstrap/scripts/$relname" ]; then
                                        cd /usr/share/debootstrap/scripts
                                        sudo ln -s sid $relname
                                fi
                                break
                        else
                                echo "Keyring file '/usr/share/keyrings/debian-archive-keyring.gpg' not found"
                                echo "Please install it to be able to bootstrap a debian image. Quitting..."
                                exit
                        fi
                        ;;
                "ubuntu")
                        if [ -f "/usr/share/keyrings/ubuntu-archive-keyring.gpg" ]; then
                                if [ ! -e "/usr/share/debootstrap/scripts/$relname" ]; then
                                        cd /usr/share/debootstrap/scripts
                                        sudo ln -s gutsy $relname
                                fi
                                break
                        else
                                echo "Keyring file '/usr/share/keyrings/ubuntu-archive-keyring.gpg' not found"
                                echo "Please install it to be able to bootstrap an ubuntu image. Quitting..."
                                exit
                        fi
                        ;;
                *)
                        echo "Invalid choice. Enter 1 or 2."
                        ;;
        esac
done

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
        sudo cp -fv /etc/resolv.conf $mp/etc/resolv.conf
        # get the 'debumin' script to run inside chroot environment
        curl -fO https://raw.githubusercontent.com/suivue/scripts/refs/heads/main/debumin.sh
        chmod +x debumin.sh
        sudo mv debumin.sh $mp/usr/local/bin/
        sudo chroot $mp bash -c 'debumin.sh;bash'
}

unmount_all() {
       #sudo umount $mp/{dev,proc,sys}
       sudo umount -R $mp
       sudo kpartx -d -v $HOME/VirtualMachines/${relname}.raw
}

# First create img file (as regular user)
mkrawimg
# Now we can call any function that needs root/sudo permission
# Install debootstrap if not installed
sudo apt-get install debootstrap kpartx qemu-system-x86 -y
fmtrawimg
boot_strap
switch_root
unmount_all

