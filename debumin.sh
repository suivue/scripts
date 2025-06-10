#! /bin/bash
#
# This script is companion script to sv-deboostrap.sh
# This is intended to run inside the initial chrooted debian/ubuntu
# minimal base system in order to install kernel and other essential sw.
#

sleep 10

export PS1="(chroot) \u@\h:\w # "
export DEBIAN_FRONTEND=noninteractive

# Add/update sources.list entry
#
distro=$(cat /etc/os-release | grep '^ID=' | cut -d"=" -f2)
relname=$(cat /etc/os-release | grep 'CODENAME' | cut -d"=" -f2)
loopN=$(losetup | awk 'NR==2 { print $1}' | cut -d'/' -f3)

if [[ "$distro" == "debian" ]]; then
        url="http://deb.debian.org/debian"
	securl="http://security.debian.org/debian-security"
	components="main non-free-firmware"
	keyring="/usr/share/keyrings/debian-archive-keyring.gpg"
elif [[ "$distro" == "ubuntu" ]]; then
	url="http://archive.ubuntu.com/ubuntu/"
	securl="http://security.ubuntu.com/ubuntu/"
	components="main restricted universe multiverse"
	keyring="/usr/share/keyrings/ubuntu-archive-keyring.gpg"
fi

cat << EOF > /etc/apt/sources.list.d/${relname}.sources
Types: deb
URIs: $url
Suites: $relname ${relname}-updates
Components: $components
Signed-By: $keyring

Types: deb
URIs: $securl
Suites: ${relname}-security
Components: $components
Signed-By: $keyring
EOF

echo "#The sources have moved to individual '.sources' files inside /etc/apt/sources.list.d directory" > /etc/apt/sources.list

# optional if proxy has to be setup
# echo 'Acquire::http::Proxy "http://192.168.3.222:8000";' > /etc/apt/apt.conf.d/99proxy

# Refresh apt database and upgrade system before proceding.
#
apt-get update
apt-get dist-upgrade

# Make sure you write '/etc/fstab' otherwise system will not boot later.
#
echo "UUID=$(blkid /dev/mapper/${loopN}p2 -s UUID -o value) / ext4 noatime 0 1" > /etc/fstab
echo "UUID=$(blkid /dev/mapper/${loopN}p1 -s UUID -o value) /boot/efi vfat umask=0077 0 1" >> /etc/fstab

# Install linux kernel and bootloader as a minimum.
# 'grub2' package will install 'grub-pc' by default. So install 'grub-efi'
# For efi version, grub-install does not require device name to be passed
#
apt-get install linux-image-generic grub-efi -y
grub-install
update-grub

# Install any other software you desire to have on a minimal environment.
# e.g., nano to edit files and network-manager to configure network.
#
apt-get install bash-completion file nano network-manager -y

# If using NetworkManager, following entry is required so that it manages
# all the devices.
#
cat << EOF > /etc/NetworkManager/conf.d/01-nm-manage.conf
[keyfile]
unmanaged-devices=none
EOF

echo $relname > /etc/hostname

# passwd for root
#
printf "\nSetting password for root\n"
passwd

# Add user for reqular use.
#useradd -m -G adm,cdrom,sudo,dip,plugdev -s /bin/bash $distro
#passwd $distro
# optionally remove proxy configuration if set before
# rm /etc/apt/apt.conf.d/99proxy

rm /usr/local/bin/debumin.sh

printf "Installation of a minimal/usable debian/ubuntu vm is done "
printf "at this stage. Continue to use or exit.\n"

