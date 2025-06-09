#! /bin/sh
#
# This script is companion script to sv-deboostrap.sh
# This is intended to run inside the initial chrooted debian/ubuntu 
# minimal base system in order to install kernel and other essential sw.
#

# Once the minimal base system is installed chroot into it and install
# kernel and bootloader as a minimum.
export PS1="(chroot) $PS1"
export DEBIAN_FRONTEND=noninteractive

# Add/update sources.list entry
distro=$(cat /etc/os-release | grep '^ID=' | cut -d"=" -f2)
relname=$(cat /etc/os-release | grep 'CODENAME' | cut -d"=" -f2)

if [ "$distro" == "debian" ]
then
cat << EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian $relname main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $relname-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $relname-updates main contrib non-free non-free-firmware
EOF
elif [ "$distro" == "ubuntu" ]
then
cat << EOF > /etc/apt/sources.list
deb http://archive.ubuntu.com/ubuntu/ $relname main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $relname-security restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ $relname-updates restricted universe multiverse
EOF
fi

# optional if proxy has to be setup
# echo 'Acquire::http::Proxy "http://192.168.3.222:8000";' > /etc/apt/apt.conf.d/99proxy
apt-get update
apt-get dist-upgrade


# Make sure you write '/etc/fstab' otherwise system will not boot later.
echo "UUID=$(blkid /dev/mapper/${loopN}p2 -s UUID -o value) / ext4 noatime 0 1" > /etc/fstab
echo "UUID=$(blkid /dev/mapper/${loopN}p1 -s UUID -o value) /boot/efi vfat umask=0077 0 1" >> /etc/fstab

# Install linux kernel and bootloader as a minimum.
apt-get install linux-image-generic grub2 -y
grub-install # does not require device name to be passed 
update-grub

# Install any other software you desire to have on a minimal environment.
#
apt-get install bash-completion file nano network-manager
# Desktop-environment if needed; There should be a '^' at the end as per
# instruction on the referenced source.
#apt-get install ubuntu-mate-desktop^

# If using NetworkManager, following entry is required so that it manages
# all the devices.
cat << EOF > /etc/NetworkManager/conf.d/01-nm-manage.conf
[keyfile]
unmanaged-devices=none
EOF

echo $relname > /etc/hostname
# Add user for reqular use.
useradd -m -G adm,cdrom,sudo,dip,plugdev -s /bin/bash $distro
passwd $distro
# optionally remove proxy configuration if set before
# rm /etc/apt/apt.conf.d/99proxy

# passwd for root
printf "\nSetting password for root\n"
passwd

rm /usr/local/bin/minstalldebu.sh

# Installation of a minimal/usable debian/ubuntu vm is done at this
# stage. Continue to use or exit.
