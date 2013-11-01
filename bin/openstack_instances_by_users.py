#!/usr/bin/env python
# -*- coding: utf-8 -*-#
# @(#)openstack_instances_by_users.py
#
#
# Copyright (C) 2013, GC3, University of Zurich. All rights reserved.
#
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA

__docformat__ = 'reStructuredText'
__author__ = 'Antonio Messina <antonio.s.messina@gmail.com>'

import argparse
import sys
from collections import defaultdict

# Note: we assume that keystone is running on the same machine as
# nova!
from keystone import config
from keystone.openstack.common import importutils

CONF = config.CONF

from nova import flags

from nova import db
from nova import context
from nova.compute import instance_types
from nova.openstack.common import cfg
from nova.openstack.common import log as logging

logging.setup("nova")
log = logging.getLogger("nova")

FLAGS = flags.FLAGS
args = flags.parse_args(['openstack_free_usage'])

def cmp_by_name(x, y):
    return cmp(x,y)

def main(args):

    CONF(default_config_files=['/etc/keystone/keystone.conf'], project='keystone')

    identity = importutils.import_object(CONF.identity.driver)

    ctxt = context.get_admin_context()
    instances = db.instance_get_all(ctxt)

    instances_by_uid = defaultdict(list)
    for vm in instances:
        instances_by_uid[vm.user_id].append(vm)

    instances_by_user = {}
    # This loop is used to re-order in alphabetic order the instances
    for user_id, vms in instances_by_uid.items():
        try:
            user = identity.get_user(user_id)['name']
        except:
            user = 'UNKNOWN_%s' % user_id
        instances_by_user[user] = vms

    keys = instances_by_user.keys()
    cmp_by = cmp_by_name

    if args.sort == 'vms':
        def cmp_by_vms(x, y):
            return cmp(len(instances_by_user[x]),
                       len(instances_by_user[y]))
        cmp_by = cmp_by_vms
    elif args.sort == 'cpus':
        def cmp_by_cpus(x, y):
            return cmp(sum(i.vcpus for i in instances_by_user[x]),
                       sum(i.vcpus for i in instances_by_user[y]))
        cmp_by = cmp_by_cpus

    for user in sorted(keys, cmp=cmp_by, reverse=args.reverse):
        vms = instances_by_user[user]

        print "%s (%d vms, %d vcpus)" % (user, len(vms), sum([v.vcpus for v in vms]))
        for vm in vms:
            try:
                tenant = identity.get_tenant(vm.project_id)['name']
            except:
                tenant = 'UNKNOWN_TENANT_%s' % vm.project_id
            print "  %s, %d cpus (flavor %s), %s, created at %s, %s, project %s" % (
                vm.hostname, vm.vcpus, vm.instance_type.name,
                vm.host, vm.created_at.strftime('%d/%m/%Y, %H:%M'),
                vm.vm_state, tenant
                )
        print

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-s', '--sort', help="Sort order. One of: name, cpus, vms", default='name')
    parser.add_argument('-r', '--reverse', help="Reverse order", action="store_true")
    args = parser.parse_args()
    sys.argv = ['openstack_instances_by_users']
    main(args)
