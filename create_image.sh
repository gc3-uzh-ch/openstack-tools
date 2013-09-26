#!/bin/bash
# @(#)create_image.sh
#
#
#  Copyright (C) 2013, GC3, University of Zurich. All rights
#  reserved.
#
#  This program is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; either version 2 of the License, or (at your
#  option) any later version.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#

PROG="$(basename $0)"

usage () {
cat <<EOF
Usage: $PROG [options] kickstart name

A short description of what the program does should be here,
but it's not (yet).

Options:

  --help, -h  Print this help text.

EOF
}


## helper functions
die () {
  rc="$1"
  shift
  (echo -n "$PROG: ERROR: ";
      if [ $# -gt 0 ]; then echo "$@"; else cat; fi) 1>&2
  exit $rc
}

warn () {
  (echo -n "$PROG: WARNING: ";
      if [ $# -gt 0 ]; then echo "$@"; else cat; fi) 1>&2
}

have_command () {
  type "$1" >/dev/null 2>/dev/null
}

require_command () {
  if ! have_command "$1"; then
    die 1 "Could not find required command '$1' in system PATH. Aborting."
  fi
}

is_absolute_path () {
    expr match "$1" '/' >/dev/null 2>/dev/null
}


## parse command-line 

short_opts='hd:u'
long_opts='help,distribution:,upload-to-glance'

if [ "x$(getopt -T)" != 'x--' ]; then
    # GNU getopt
    args=$(getopt --name "$PROG" --shell sh -l "$long_opts" -o "$short_opts" -- "$@")
    if [ $? -ne 0 ]; then
        die 1 "Type '$PROG --help' to get usage information."
    fi
    # use 'eval' to remove getopt quoting
    eval set -- $args
else
    # old-style getopt, use compatibility syntax
    args=$(getopt "$short_opts" "$@") 
    if [ $? -ne 0 ]; then
        die 1 "Type '$PROG --help' to get usage information."
    fi
    set -- $args
fi

DISTR=centos6
UPLOAD_TO_GLANCE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --distribution|-d)
            shift
            DISTR=$1
            ;;
        --upload-to-glance|-u)
            shift
            UPLOAD_TO_GLANCE=1
            ;;
        --help|-h) usage; exit 0 ;;
        --) shift; break ;;
    esac
    shift
done

ksfile=$1
name=$2

if [ -z "$name" -o -z "$ksfile" ]; then
    die 1 "Usage: $0 kickstart name"
fi
ks=$(basename $ksfile)

if ! [ -f "$ksfile" ]; then
    die 2 "Kickstart file $ks not found"
fi

case $DISTR in 
    centos6)
        OSVARIANT=rhel6
        OSLOCATION=http://mirrors.kernel.org/centos/6/os/x86_64
        OSEXTRAARGS="ks=file:///$ks"
        ;;
    precise)
        OSVARIANT=ubuntuprecise
        OSLOCATION=http://archive.ubuntu.com/ubuntu/dists/precise/main/installer-amd64/
        OSEXTRAARGS="auto=true url=file:///$ks DEBCONF_DEBUG=5 netcfg/get_hostname=ubuntu"
        ;;
    quantal)
        OSVARIANT=ubuntuquantal
        OSLOCATION=http://archive.ubuntu.com/ubuntu/dists/quantal/main/installer-amd64/
        OSEXTRAARGS="auto=true url=file:///$ks DEBCONF_DEBUG=5 netcfg/get_hostname=ubuntu"
        ;;
    raring)
        OSVARIANT=ubuntuquantal
        OSLOCATION=http://archive.ubuntu.com/ubuntu/dists/raring/main/installer-amd64/
        OSEXTRAARGS="auto=true url=file:///$ks DEBCONF_DEBUG=5 netcfg/get_hostname=ubuntu"
        ;;
    *)
        die 2 "Distribution not supported."
        ;;
esac

require_command virt-install virt-install
require_command virt-sysprep
require_command virt-sparsify
require_command glance

sudo virt-install --version >/dev/null  || die 3 "sudo command might not work. Check that you can run commands as root using sudo."

sanitized_name=$(echo -n "$name" | tr '[:space:]' '_' | tr -s '_' | tr '[A-Z]' '[a-z]')
imgfile=$sanitized_name.img
qcowfile=$sanitized_name.qcow2

    # --nographics --os-type=linux \

echo "Running virt-install"
virt-install --name "$sanitized_name" \
    --connect=qemu:///session \
    --ram 1024 --cpu host --vcpus 1 \
    --os-type=linux --nographics \
    --os-variant=$OSVARIANT --location=$OSLOCATION \
    --initrd-inject=$ksfile --extra-args="$OSEXTRAARGS text console=tty0 utf8 console=ttyS0,115200" \
    --disk path=`pwd`/$imgfile,size=4,bus=virtio --force --noreboot \
    || die 9 "Virt-install failed1"

echo "Preparing image for cloud"
sudo virt-sysprep --no-selinux-relabel -a $imgfile \
    || die 9 "Virt-sysprep failed1"

echo "Sparsify disk file and converting to qcow2"
sudo virt-sparsify --convert qcow2  $imgfile $qcowfile \
    || die 9 "Virt-sparsify failed1"

if [ $UPLOAD_TO_GLANCE -eq 1 ]
then
    echo "Uploading to glance"
    echo glance image-create --name "$name" --disk-format qcow2 --container-format bare --is-public false --file $qcowfile
fi

echo
echo "Creation of image done."
echo "Raw image:   $imgfile"
echo "QCOW2 image: $qcowfile"

