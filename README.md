openstack-tools
===============

This is a collection of tools useful to manage/inspect the status of
an OpenStack installation.

Please note that these tools have been tested only on Ubuntu 12.04,
OpenStack Folsom!

``create_image.sh``
-------------------

This tool is used to create and possibly upload to a glance instance a
virtual cloud-ready virtual disk. The tool allow you to create virtual
machines for one of the following distributions:

* CentOS 5, 6
* Ubuntu Precise Pangolin 12.04 LTS
* Ubuntu Quantal Quetzal 12.10
* Ubuntu Raring Ringtail 13.04
* Ubuntu Trusty Tahr Ringtail 14.04 LTS
* Debian Wheezy 7

In order to do this, it uses ``virt-install`` command and a kickstart
or a preseed, depending if you are installing a CentOS or a
Debian/Ubuntu system. Predefined kickstart and preseeds are stored in
the ``etc/`` directory, but you can customize them or supply your own
file.

The following packages are required:

* virtinst (``virt-install`` command)
* libguestfs-tools (``virt-sysprep`` and ``virt-sparsify`` commands)
* python-glanceclient (``glance`` command, required only to upload the
  image to OpenStack)

Customization performed on the created images consist of:
* install cloud-init and cloud-initramfs-growroot
* create a `gc3-user` user (instead of the distro default) and
  configure cloud-init accordingly
* ensure the cloud-init datasource include EC2
* enable serial console (useful to show console logs from OpenStack)
* ensure the system has ssh host keys
* configure via dhcp any network interface (not just the first one)


Tools present in the ``bin`` directory
======================================

``openstack-accounting-usage``
------------------------------

A script to read out the OpenStack mysql database and create a report
about walltime and volume usage on a *per user base*.

To use this script you should create a mysql user that has read-only
rights.


``openstack-check-quotas``
--------------------------

Check that nova and cinder quotas in OpenStack reflect the actual
usage of the cloud. This is done by checking the quota information
stored on the database against the list of running VMs.

An option `--update-usages` allows you to also *fix* the quota
tables in the DB by updating the information on the actual usage,
based on the *real* actual usage.

If option `-k` is given, then user and tenant IDs are translated into
their names using `Keystone`. This also requires that you pass
`--os-username`, `--os-password`, `--os-tenant-name` and
`--os-auth-url` options, or you set the corresponding environment
variable before calling this command.

The script will look for configuration files ``/etc/nova/nova.conf``
and ``/etc/cinder/cinder.conf``, in order to get the `sql_connection`
strings and access the nova and cinder databases. You can specify
different path for the configuration files using
`--nova-config-file` and `--cinder-config-file`, or you can specify
a SQLAlchemy-like connection string using `--nova-sql-string` and
`--cinder-sql-string`.


``openstack-check-spurious-vms``
--------------------------------

This tool will check if there are Virtual Machines running on some
compute node which are not related to any OpenStack instance.

If `-k` option is given, then these *spurious* machines are terminated
(by issuing ``virsh destroy`` on the compute node)

In order to make this command work you need to:

* supply a valid ``/etc/nova/nova.conf``. This tool uses the same APIs
  used by the ``nova-manage`` tools. As such, you will need to provide
  a proper ``/etc/nova/nova.conf`` in order to be able to access the
  database.

* ensure that your user can `ssh` without password on all the compute
  nodes.

* ensure that `virsh` is installed on the compute nodes. This also
  mean that the command will only work if you have ``virsh`` installed
  on the compute node and if ``libvirt.LibvirtDriver`` is used as
  ``compute_driver``.


``openstack-create-delete-user``
--------------------------------

This command line tool automates the creation and deletion of an user
in Keystone. It automatically:

* creates/delete the user
* associate the user to the requested role (by default: `Member`)
* create the tenant if it doesn't exist (and `--create-project` option
  is given)
* set rules for the `default` security group in case a new tenant is
  created
* remembers you to add the user to the `cloud` mailing list (very GC3-specific!)


``openstack-free-usage``
------------------------

This tool is used to check how many virtual machines your OpenStack
can still run for each flavor. Also, it allow you to *simulate* the
existence of a flavor defined using command line options.

By default, a list of flavor is printed to standard output, and two
numbers for each flavor next to it is displayed: the number of virtual
machines that can be started using that flavor considering the current
usage, and the maximum number of instances with that flavor that your
cloud can run.

Option `-f` allows you to specify a list of flavors. If this option is
given, only these flavors will be considered and printed

Please note that this tool also checks the extra specs and confront
them with the aggregates. This behavior reflects your installation
only if your `nova.conf` defines the
`AggregateInstanceExtraSpecsFilter` filter:

    scheduler_default_filters=AggregateInstanceExtraSpecsFilter,...

Option `--simulate`` instead will allow you to define a new flavor
(using options `-n`, `-c`, `-m`, `-r`, `-e` and `--extra-specs` to
define the name, the number of cpus, the amount of ram, root disk,
ephemeral disk and extra specifications) and to check also against
this fake flavor. This is very useful to check how many virtual
machines your cloud will be able to run with a specific flavor you
want to create *before* actually creating it.


By adding multiple `-v` options you will get a more verbose output:

``-v``
    also print the number of compute nodes, total number of CPUs, CPUs
    currently in use, total ram, total ram in use, total disk, total
    disk in use.

``-vv``
    also print information about each flavor (vcus, ram, disk etc)

``-vvv`` also print one line for each compute node, with the number of
    free/total cpus, free/total ram, free/total disk

This tool uses the same APIs used by the ``nova-manage`` tools. As
such, you will need to provide a proper ``/etc/nova/nova.conf`` in
order to be able to access the database.


``openstack-get-vm-from-ip``
----------------------------

This tool access the database and reports all the virtual machines
that ever used a specific IP address.

Optionally you can specify a start and end date, to select only the
instances that were running within that time range.

If you provide valid OpenStack credentials (either with `--os-*` options
or setting the corresponding `OS_*` environment variables) and supply
the `-k` option, project and user IDs are converted into project and
user names.

Please note that this command only work with fixed IPs or
automatically assigned floating IPs, it does not work with "proper"
floating IPs, because the required information are not stored in the
database.


``openstack-instances-by-users``
--------------------------------

This tool will print all the instances currently running grouped by
user. For each instance a few information are printed (name, nr. of
cpus, flavor, hostname of the compute node, when has been created,
status and the project name). It will also print how many VMs and
vCPUs an user is currently using.

You can show information about only a few users with the `-u` option,
followed by the list of users you are interested to.

You can sort the output based on user `name`, number of `cpus` used or
number of `vms` currently running (default: sort by `name`)

This tool uses the same APIs used by the ``nova-manage`` tools. As
such, you will need to provide a proper ``/etc/nova/nova.conf`` in
order to be able to access the database.


``openstack-mkpasswd``
----------------------

Hash a given password and output it in a format suitable for direct
insertion in Keystone's user database.

This is primarily meant to be used in all cases where users cannot
change the password themselves: with this little utility, an OpenStack
admin can replace (or set anew) a password entry without being told
the cleartext in any way.
