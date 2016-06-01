# This is a basic CentOS 6 spin designed to work in OpenStack and other
# virtualized environments. It's configured with cloud-init so it will
# take advantage of ec2-compatible metadata services for provisioning
# ssh keys and user data.

# Basic kickstart bits
text
skipx
cmdline
install

# Installation path
url --url=http://mirrors.kernel.org/centos/6/os/x86_64

# Repositories
repo --name=base --baseurl=http://mirrors.kernel.org/centos/6/os/x86_64
repo --name=updates --baseurl=http://mirrors.kernel.org/centos/6/updates/x86_64
repo --name=epel --baseurl=http://mirrors.kernel.org/fedora-epel/6/x86_64
# repo --name=cloud-init --baseurl=http://repos.fedorapeople.org/repos/openstack/cloud-init/epel-6/

# Common configuration
rootpw --iscrypted $1$fakehash-bruteforcetocrackitnow
lang en_US.UTF-8
keyboard us
timezone --utc UTC
network --onboot=on --bootproto=dhcp
firewall --enabled
auth --useshadow --enablemd5
firstboot --disable
poweroff

# TODO(dtroyer): selinux isn't totally happy yet
#selinux --enforcing
selinux --permissive

# Simple disk layout
zerombr
clearpart --all --initlabel
bootloader --location=mbr --append="console=tty console=ttyS0 notsc"
part / --size 100 --fstype ext4 --grow

# Start a few things
services --enabled=acpid,ntpd,sshd,cloud-init

# Bare-minimum packages
%packages --nobase
@server-policy
acpid
logrotate
ntp
ntpdate
openssh-clients
rng-tools
rsync
screen
tmpwatch
wget

epel-release
cloud-init

# Some things from @core we can do without in a minimal install
-biosdevname
-NetworkManager
-sendmail

%end

# Fix up the installation
%post

# Cleanup after yum
yum clean all

# Rename the default cloud-init user to 'centos'

# cloud-init 0.6 config format
#sed -i 's/^user: ec2-user/user: centos/g' /etc/cloud/cloud.cfg

# cloud-init 0.7 config format
#sed -i 's/ name: cloud-user/ name: centos/g' /etc/cloud/cloud.cfg
cp /etc/cloud/cloud.cfg /etc/cloud/cloud.cfg.orig
sed -i 's/name: cloud-user/name: centos\
    lock_passwd: True\
    gecos: CentOS User\
    groups: \[adm, audio, cdrom, dialout, floppy, video, dip\]\
    sudo: \[\"ALL=(ALL) NOPASSWD:ALL\"\]\
    shell: \/bin\/bash/' /etc/cloud/cloud.cfg

# Also ensure there is no "requiretty" in sudoers
sed -i 's/\(Defaults.*requiretty\)/# \1/g' /etc/sudoers

# Turn off additional services
chkconfig postfix off


# Tweak udev to not auto-gen virtual network devices
cat <<EOF >/tmp/udev.patch.1
# ignore KVM virtual interfaces
ENV{MATCHADDR}=="52:54:00:*", GOTO="persistent_net_generator_end"
# ignore VMWare virtual interfaces
ENV{MATCHADDR}=="00:0c:29:*|00:50:56:*", GOTO="persistent_net_generator_end"
# ignore Hyper-V virtual interfaces
ENV{MATCHADDR}=="00:15:5d:*", GOTO="persistent_net_generator_end"
# ignore Eucalyptus virtual interfaces
ENV{MATCHADDR}=="d0:0d:*", GOTO="persistent_net_generator_end"
# ignore Ravello Systems virtual interfaces
ENV{MATCHADDR}=="2c:c2:60:*", GOTO="persistent_net_generator_end"
# ignore OpenStack default virtual interfaces
ENV{MATCHADDR}=="fa:16:3e:*", GOTO="persistent_net_generator_end"

EOF
# sed-ism: we need to N below to make this an insert rather than an append
sed -e '/\# do not use empty address/ {
  h
  r /tmp/udev.patch.1
  g
  N
}' \
  /lib/udev/rules.d/75-persistent-net-generator.rules >/etc/udev/rules.d/75-persistent-net-generator.rules


# Set up to grow root in initramfs
cat << EOF > 05-grow-root.sh
#!/bin/sh

/bin/echo
/bin/echo Resizing root filesystem

/bin/echo "d
n
p
1


w
" | /sbin/fdisk -c -u /dev/vda
/sbin/e2fsck -f /dev/vda1
/sbin/resize2fs /dev/vda1
EOF

chmod +x 05-grow-root.sh

dracut --force --include 05-grow-root.sh /mount --install 'echo fdisk e2fsck resize2fs' /boot/"initramfs-grow_root-$(ls /boot/|grep initramfs|sed s/initramfs-//g)" $(ls /boot/|grep vmlinuz|sed s/vmlinuz-//g)
rm -f 05-grow-root.sh

tail -4 /boot/grub/grub.conf | sed s/initramfs/initramfs-grow_root/g| sed s/CentOS/ResizePartition/g | sed s/crashkernel=auto/crashkernel=0@0/g >> /boot/grub/grub.conf

# In case you want to run the kernel & initramfs that expands the partition only once
# echo "savedefault --default=1 --once" | grub --batch
# Otherwise:
sed -i s/^default=.*/default=1/g /boot/grub/grub.conf

# Leave behind a build stamp
echo "build=$(date +%F.%T)" >/etc/.build

%end
