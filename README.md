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

* CentOS 6
* Ubuntu Precise Pangolin 12.04
* Ubuntu Quantal Quetzal 12.10
* Ubuntu Raring Ringtail 13.04
* Debian Wheezy 7.1

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


Tools present in ``bin`` directory
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


``openstack_accounting_usage.py``
---------------------------------

A script to read out the OpenStack mysql database and create a report
about walltime and volume usage on a *per user base*.

To use this script you should create a mysql user that has read-only
rights.

``openstack_check_spurious_vms.py``
-----------------------------------

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


``openstack_free_usage.py``
---------------------------

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

Option `--simulate`` instead will allow you to define a new flavor
(using options `-n`, `-c`, `-m`, `-r` and `-e` to define the name, the
number of cpus, the amount of ram, root disk and ephemeral disk) and
to check also against this fake flavor. This is very useful to check
how many virtual machines your cloud will be able to run with a
specific flavor you want to create *before* actually creating it.

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
  
``openstack_instances_by_users.py``
-----------------------------------

This tool will print all the instances currently running grouped by
user. For each instance a few information are printed (name, nr. of
cpus, flavor, hostname of the compute node, when has been created,
status and the project name). It will also print how many VMs and
vCPUs an user is currently using.

You can show information about only a few users with the `-u` option,
followed by the list of users you are interested to.

This tool uses the same APIs used by the ``nova-manage`` tools. As
such, you will need to provide a proper ``/etc/nova/nova.conf`` in
order to be able to access the database.

``openstack_test_quotas.py``
----------------------------

Check that quotas in OpenStack reflect the actual usage of the
cloud. This is done by checking the quota information stored on
the database against the list of running VMs.
