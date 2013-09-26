#!/usr/bin/python
# -*- coding: utf-8 -*-
'''
Created on 29/may/2013

@author: joelcasutt
'''
from optparse import OptionParser
import MySQLdb as mdb
import datetime
import sys
import getpass

class openstack_accounting( object ):
  """
  A script to read out the OpenStack mysql database and create a report about walltime and volume usage on a per user base. To use this script you should create a mysql user that has read-only rights.
  """

  # Default values for the different options and Constants 
  DEFAULT_MYSQL_USER = "root"
  DEFAULT_MYSQL_PASSWORD = ""
  DEFAULT_MYSQL_HOST = "localhost"
  DEFAULT_CORES_SWITCH = False
  DEFAULT_PASSWORD = ""
  DEFAULT_KEYSTONEDB = "keystone"
  DEFAULT_NOVADB = "nova"
  DEFAULT_CINDERDB = "cinder"
  DEFAULT_FILE = "/tmp/OS_accounting.txt"

  # Variables
  usage = "usage %prog [options]"
  optionParser = None
  options = None
  args = None
  version = "1.0"
  password = None
  keystonedb = None
  novadb = None
  cinderdb = None
  host = None
  username = None
  password = None
  outputfile = None 

  # constructor
  def __init__( self ):
    self.name = sys.argv[0].split("/")[-1]
    self.optionParser = OptionParser(version="%s v.%s" % (self.name, self.version))

  # getters and setters for the default private variables and constants
  def getDefaultUsername( self ):
    return self.DEFAULT_MYSQL_USER

  def getDefaultHost( self ):
    return self.DEFAULT_MYSQL_HOST

  def getDefaultCoresSwitch( self ):
    return self.DEFAULT_CORES_SWITCH 

  def getDefaultPassword( self ):
    return self.DEFAULT_PASSWORD
 
  def getDefaultKeystonedb( self ):
    return self.DEFAULT_KEYSTONEDB

  def getDefaultNovadb( self ):
    return self.DEFAULT_NOVADB

  def getDefaultCinderdb( self ):
    return self.DEFAULT_CINDERDB

  def getDefaultFile( self ):
    return self.DEFAULT_FILE

  def getKeystonedb( self ):
    return self.keystonedb

  def setKeystonedb( self, newKeystonedb ):
    self.keystonedb = newKeystonedb

  def getNovadb( self ):
    return self.novadb

  def setNovadb( self, newNovadb ):
    self.novadb = newNovadb

  def getCinderdb( self ):
    return self.cinderdb

  def setCinderdb( self, newCinderdb ):
    self.cinderdb = newCinderdb

  def getHost( self ):
    return self.host

  def setHost( self, newHost ):
    self.host = newHost

  def getUsername( self ):
    return self.username

  def setUsername( self, newUsername ):
    self.username = newUsername

  def getPassword( self ):
    return self.password

  def setPassword( self, newPassword ):
    self.password = newPassword

  def getFilename( self ):
    return self.outputfile

  def setFilename( self, newOutputfile ):
    self.outputfile = newOutputfile

  # read out the options from the command-line
  def createParser( self ): 
    optionParser = self.optionParser
    optionParser.add_option("-u",
      "--username",
      dest="username",
      help="The username to use to connect to the DB. [default: %default]",
      default = self.getDefaultUsername())
   
    optionParser.add_option("-H",
      "--host",
      dest="host",
      help="The host to use to connect to the DB. [default: %default]",
      default = self.getDefaultHost())
                 
    optionParser.add_option("-p",
      "--password",
      action="callback",
      callback=self.optional_arg('empty'),
      dest="password",
      help="Use this option to specify a password to connect to your DB. If this option is not set the script uses the default, if it is set but empty you will be prompted to enter a password [default: %s]" % self.getDefaultPassword())

    optionParser.add_option("-k",
      "--keystonedb",
      dest="keystonedb",
      help="sets the name of the keystone database [default: %default]",
      default = self.getDefaultKeystonedb())

    optionParser.add_option("-n",
      "--nova",
      dest="novadb",
      help="sets the name of the nova database [default: %default]",
      default = self.getDefaultNovadb())

    optionParser.add_option("-c",
      "--cinder",
      dest="cinderdb",
      help="sets the name of the cinder database [default: %default]",
      default = self.getDefaultCinderdb())

    optionParser.add_option("-f",
      "--file",
      action="callback",
      callback=self.optional_arg('empty'),
      dest="outputfile",
      help="if given, the output is written additionally to a file. If no file is specified the default value is used. [default: %s]" % self.getDefaultFile())
                 
  def optional_arg(self, arg_default):
    def func(option,opt_str,value,parser):
        if parser.rargs and not parser.rargs[0].startswith('-'):
            val=parser.rargs[0]
            parser.rargs.pop(0)
        else:
            val=arg_default
        setattr(parser.values,option.dest,val)
    return func
 
  def readOptions( self ):
    optionParser = self.optionParser        
    (self.options, self.args) = optionParser.parse_args()
    if not self.options.password:
      self.setPassword(self.getDefaultPassword())
    elif self.options.password is "empty":
      self.setPassword(getpass.getpass())
    else:
      self.setPassword(self.options.password)
    if not self.options.outputfile:
      self.setFilename(None)
    elif self.options.outputfile is "empty":
      self.setFilename(self.getDefaultFile())
    else:
      self.setFilename(self.options.outputfile)
    self.setKeystonedb(self.options.keystonedb)
    self.setNovadb(self.options.novadb)
    self.setCinderdb(self.options.cinderdb)
    self.setHost(self.options.host)
    self.setUsername(self.options.username)

  # Fetch data from mysql
  def mysqlSelect( self, dbName, tableName, columNames ):
    con = mdb.connect(self.getHost(), self.getUsername(), self.getPassword(), dbName);
    with con:
      columns= ', '.join(map(str, columNames))
      cur = con.cursor()
      cur.execute("SELECT %s FROM %s" % (columns, tableName))
      queryResult = cur.fetchall()
    return queryResult

  def prepareUserMapping( self ):
    users = self.mysqlSelect(self.getKeystonedb(), "user", ["id","name"])
    userid_mapping = dict()
    for user in users:
      userid_mapping[user[0]] = user[1]
    return userid_mapping

  def prepareUserList( self ):
    user_output = self.mysqlSelect(self.getKeystonedb(), "user", ["id"])
    user_list = list()
    for user in user_output:
      user_list.append(user[0])
    return user_list

  def prepareDict( self, dbName, tableName, columnNames):
    mysql_data = self.mysqlSelect(dbName, tableName, columnNames)
    return_data = dict()
    now = now = datetime.datetime.now()
    one = 1
    for row in mysql_data:
      user_id = row[0]
      created_at = row[1]
      deleted_at = row[2]
      size = row[3]
      if row[2] != None:
        lifetime = abs(row[2]-row[1]).total_seconds() / 3600.0
        is_active = 0
      else:
        lifetime = abs(now-row[1]).total_seconds() / 3600.0
        is_active = 1
      eff_size = lifetime * size
      if not user_id in return_data:
        return_data[user_id] = [eff_size, is_active, one]
      else:
        return_data[user_id][0] = return_data[user_id][0] + eff_size
        return_data[user_id][1] = return_data[user_id][1] + is_active
        return_data[user_id][2] = return_data[user_id][2] + one
    return return_data

  def writeOutput( self, user_list, userid_mapping, instance_mapping, volume_mapping ):
    filename = self.getFilename()
    if not filename is None:
      f=open(filename, 'w+')
    first_row_format = "|{:^61}|{:^37}|{:^37}|"
    row_format ="|{:25}|{:^35}|{:^10}|{:^10}|{:>15.4f}|{:^10}|{:^10}|{:>15.4f}|"
    second_row_format ="|{:^25}|{:^35}|{:^10}|{:^10}|{:^15}|{:^10}|{:^10}|{:^15}|"
    row_length = 139
    print "-" * row_length
    print first_row_format.format("User","Instances","Volumes")
    print "-" * row_length
    print second_row_format.format("Name", "ID", "total", "active", "Walltime [h]", "total", "active", "GBh")
    print "=" * row_length
    for user in user_list:
      (username, user_id, user_instances, user_active_instances, user_walltime, user_volumes, user_active_volumes, user_gbh) = ( 0, ) * 8
      user_id = user
      if user_id in userid_mapping:
        username = userid_mapping[user_id]
      if user_id in instance_mapping:
        user_walltime = instance_mapping[user_id][0]
        user_active_instances = instance_mapping[user_id][1]
        user_instances = instance_mapping[user_id][2]
      if user_id in volume_mapping:
        user_gbh = volume_mapping[user_id][0]
        user_active_volumes = volume_mapping[user_id][1]
        user_volumes = volume_mapping[user_id][2]
      print row_format.format(username, user_id, user_instances, user_active_instances, user_walltime, user_volumes, user_active_volumes, user_gbh)
      print "-" * row_length
      if not filename is None:
        print >> f, "%s, %s, %d, %d, %.4f, %d, %d, %.4f" % (username, user_id, user_instances, user_active_instances, user_walltime, user_volumes, user_active_volumes, user_gbh)

# Run the script
def main():
  reader = openstack_accounting()
  reader.createParser()
  reader.readOptions()
  user_list = reader.prepareUserList()
  userid_mapping = reader.prepareUserMapping()
  instance_mapping = reader.prepareDict(reader.getNovadb(), "instances", ["user_id","created_at", "deleted_at", "vcpus"])
  volume_mapping = reader.prepareDict(reader.getCinderdb(), "volumes", ["user_id","created_at", "deleted_at", "size"])
  reader.writeOutput(user_list, userid_mapping, instance_mapping, volume_mapping)    

if __name__ == '__main__':
  main()

