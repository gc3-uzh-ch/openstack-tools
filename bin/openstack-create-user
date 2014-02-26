#!/usr/bin/env python
# -*- coding: utf-8 -*-# 
# @(#)openstack-create-user.py
# 
# 
# Copyright (C) 2014, GC3, University of Zurich. All rights reserved.
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
import getpass
import os
import sys

from keystoneclient.v2_0 import client as kclient
from novaclient import client as nclient

DEFAULT_SECGROUP_RULES = [
    # proto, FromPort, ToPort, CIDR
    ['icmp', '-1', '-1', '0.0.0.0/0'],
    ['tcp', '22', '22', '0.0.0.0/0'],
]
USERS_MAILING_LIST='https://lists.uzh.ch/gc3.lists.uzh.ch/sympa/review/cloud'

    
class EnvDefault(argparse.Action):
    # This is took from
    # http://stackoverflow.com/questions/10551117/setting-options-from-environment-variables-when-using-argparse
    def __init__(self, envvar, required=True, default=None, **kwargs):
        if not default and envvar:
            if envvar in os.environ:
                default = os.environ[envvar]
        if required and default:
            required = False
        super(EnvDefault, self).__init__(default=default, required=required, 
                                         **kwargs)

    def __call__(self, parser, namespace, values, option_string=None):
        setattr(namespace, self.dest, values)


def tenant_postinstall(user, tenant, client, args):
    """
    Tenant post-configuration
    """
    # Fix security group rules
    uclient = nclient.Client('1.1', user.name, args.password, args.project,
                             args.os_auth_url)
    secgroups = uclient.security_groups.list()
    secgroup = [i for i in secgroups if i.name == 'default'][0]
    for rule in DEFAULT_SECGROUP_RULES:
        try:
            uclient.security_group_rules.create(secgroup.id, *rule)
        except Exception, ex:
            print "Ignoring error '%s' when adding rule %s to security group"
            "'%s'" % (ex, rule, secgroup.name)


def user_postinstall(client, args):
    print """
The user `%s` (%s) has been created.
You should add its email address to the cloud mailing list.

Open the page:

    %s

and add the following email address:

    %s
""" % (args.username, args.name, USERS_MAILING_LIST, args.email)


def add_user(args):
    if not args.password:
        for i in range(3):
            pwd = getpass.getpass("Enter new password: ")
            pwd2 = getpass.getpass("Retype new password: ")
            if pwd != pwd2:
                print("ERROR: Passwords do not match. Please retry.")
            else:
                args.password = pwd
                break
    if not args.password:
        raise SystemExit("ERROR: Too many tries. Exiting.")
    client = kclient.Client(username=args.os_username,
                            password=args.os_password,
                            tenant_name=args.os_tenant_name,
                            auth_url=args.os_auth_url)

    users = client.users.list()
    matching_users = [u for u in users if u.name == args.username]
    USER_HAS_BEEN_CREATED=False

    if args.project:
        TENANT_HAS_BEEN_CREATED=False
        tenants = client.tenants.list()
        roles = client.roles.list()

        # Check if the tenant exists already
        matching_tenants = [t for t in tenants if t.name == args.project]
        matching_roles = [r for r in roles if r.name == args.role]

        if not matching_roles:
            raise SystemExit("Role `%s` does not exist. Aborting" % args.role)

        if not matching_tenants:
            if not args.create_project:
                raise SystemExit("Project `%s` does not exist and no `--create-project` option given. Aborting" % args.project)
            # Create the tenant
            new_tenant = client.tenants.create(args.project, description=args.project_description)
            print ("Tenant `%s` as been created with id: %s" % (args.project, new_tenant.id))
            TENANT_HAS_BEEN_CREATED=True
            args.tenant_id = new_tenant.id
        else:
            args.tenant_id = matching_tenants[0].id
            print ("Tenant `%s` has id `%s`" % (args.project, args.tenant_id))

        # Add the requested role to the user on this tenant

        user = matching_users[0] if matching_users else None
        if user:
            print "User `%s` exists already with id %s, skipping creation" % (user.name, user.id)
        else:
            user = client.users.create(args.username, args.password, args.email, tenant_id = args.tenant_id)
            print "User `%s` created with id: %s" % (user.name, user.id)
            USER_HAS_BEEN_CREATED=True

        user_roles = client.roles.roles_for_user(user.id, tenant=args.tenant_id)
        if [r for r in user_roles if r.id == matching_roles[0].id]:
            print "User `%s` already has role `%s` in tenant `%s`." % (user.name, args.role, args.project)
        else:
            client.roles.add_user_role(user.id, matching_roles[0].id, tenant=args.tenant_id)
            print "Assigned role `%s` to user `%s` in tenant `%s`" % (args.role, user.name, args.project)
        
        if TENANT_HAS_BEEN_CREATED:
            tenant_postinstall(user, new_tenant, client, args)

    else:
        if matching_users:
            print "User `%s` exists already with id %s, skipping creation" % (user.name, user.id)
        else:            
            user = client.users.create(args.username, args.password, args.email)
            print "User `%s` created with id: %s" % (user.name, user.id)
            USER_HAS_BEEN_CREATED=True

    if USER_HAS_BEEN_CREATED:
        user_postinstall(client, args)


def del_user(args):
    client = kclient.Client(username=args.os_username,
                            password=args.os_password,
                            tenant_name=args.os_tenant_name,
                            auth_url=args.os_auth_url)
    users = client.users.list()
    matching_users = [usr for usr in users if usr.name == args.username]
    if not matching_users:
        SystemExit("User '%s' does not exist." % args.username)

    matching_users[0].delete()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--os-username', action=EnvDefault, envvar="OS_USERNAME",
                        help='OpenStack administrator username. If not supplied, the value of the '
                        '"OS_USERNAME" environment variable is used.')
    parser.add_argument('--os-password', action=EnvDefault, envvar="OS_PASSWORD",
                        help='OpenStack administrator password. If not supplied, the value of the '
                        '"OS_PASSWORD" environment variable is used.')
    parser.add_argument('--os-tenant-name', action=EnvDefault, envvar="OS_TENANT_NAME",
                        help='OpenStack administrator tenant name. If not supplied, the value of the '
                        '"OS_TENANT_NAME" environment variable is used.')
    parser.add_argument('--os-auth-url', action=EnvDefault, envvar="OS_AUTH_URL",
                        help='OpenStack auth url endpoint. If not supplied, the value of the '
                        '"OS_AUTH_URL" environment variable is used.')

    # parser.add_argument('action', choices=['add', 'delete'], help="Action to perform. Can be either `add` or `delete`")
    subparsers = parser.add_subparsers(help="Specify a command")
    parser_add = subparsers.add_parser("add", help="Add an user")
    parser_add.add_argument('-p', '--project', help="Project name")
    parser_add.add_argument('--create-project', action="store_true", default=False, help="Create the project if it does not exist")
    parser_add.add_argument('--project-description', help="Project description to use when creating a new project")
    parser_add.add_argument('-r', '--role', default="Member", help="Role name")
    parser_add.add_argument('-e', '--email', required=True, help="Supply an email name")
    parser_add.add_argument('-n', '--name', help="Full name of the user")
    parser_add.add_argument('--password', help="Supply password from command line. If not specified, a password will be asked from command line")
    parser_add.add_argument('username', help='Username to create')
    parser_add.set_defaults(func=add_user)

    parser_del = subparsers.add_parser("del", help="Delete an user")
    parser_del.add_argument('--force', action="store_true", default=False, help="Do not ask for confirmation")
    parser_del.add_argument('username', help='Username to delete')
    parser_del.set_defaults(func=del_user)

    args = parser.parse_args()
    args.func(args)
