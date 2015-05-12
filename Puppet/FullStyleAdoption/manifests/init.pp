# == Class: FullStyleAdoption
#
# This is a demo class file written on the fly
#   Source material is spawned from "somehosttype" module which is pre-existing sanitized code
#   Goal is to demo both previous experience adn adherance to best practices
#
#
# === Parameters
#
# Paramenters should be set using an External Node Classifier to ensure easiest management of these
#
# [cert_file]
#   Default cert_file = "intermediate-CA.cer"
#   Should be used to customize between production and non-production environments if necessary
#
#
# [application_user]
#    Default application_user = "someappuser"
#    Used to make the system user account configurable for which user owns and managements process for application
#
#
# === Variables
#
# Here you should define a list of variables that this module would require.
#
# [*sample_variable*]
#   Explanation of how this variable affects the function of this class and if
#   it has a default. e.g. "The parameter enc_ntp_servers must be set by the
#   External Node Classifier as a comma separated list of hostnames." (Note,
#   global variables should be avoided in favor of class parameters as
#   of Puppet 2.6.)
#
# === Examples
#
#  class { 'FullStyleAdoption':
#    servers => [ 'pool.ntp.org', 'ntp.local.company.com' ],
#  }
#
# === Authors
#
# Author Name <author@domain.com>
#
# === Copyright
#
# Copyright 2015 Your name here, unless otherwise noted.
#
class FullStyleAdoption {
  include users,groups,sysctl,conf

  # Set default value for CA cert to be deployed as below
  ### This is likely candidate to be stubbed out into something else, but purpose/justifacation is unclear.
  if !$cert_file {
    $cert_file = "intermediate-CA.cer"
  }
  if !$application_user { 
    $application_user = "someappuser"
  }

  # It might be best if this were in a global registry to ensure things like UID/GID collisions don't happen.  
  #   This would be done with virtual user resources, and such, but for the sake of this example, a single properly built user is more relevant
  #    Because there is no centralized registry at this time, don't specficy a uid/gid, it could collide
  #    Drawback: This means if code is not safe, same user could have different uid/gid on different machines.

  user { 'Application User':
    name        => "$application_user",
    ensure      => present,
    allowdupe   => false,
    comment     => "This is a system service account used to run applications",
    expiry      => absent,
    groups      => "$application_user",
    password    => "!"  # This will disable password based logins.
  }

  group { 'Application User Group':
    name        => "$application_user"
  }

  # deploy snmp script to verify access to external SaaS provider.  as of 1/7/2012, it fetches this URL https://somesite.com/some/path
  file { '/opt/custom/snmp/bin/saasVendor_test':
    ensure  => present,
    require => File['/opt/custom/snmp'],
    mode => '0555',
    source  => 'puppet:///modules/someothermodule/saasVendor_test',
  }

  #Create basic filesystem paths since they are likely not properly created by packages.  Use ordering in file resource list to ensure parents are create first
  file { ["/opt/", "/opt/custom/", "/opt/custom/$application_user", "/opt/custom/$application_user/conf", "/var/custom"]:
    ensure => directory,
    owner  => "$application_user",
    group  => "$application_user",
    mode   => "0750",
    require => [User["$application_user"] ],
  }

  # SNMP report to describe present largest JavaVM footprint.  Might not be appropriate for somehosttype, only legacyhosttype?
  # collects largest from call to "ps -C java -o vsize --sort vsize"
  file { '/opt/custom/snmp/bin/java_vm_used.sh':
    ensure  => present,
    owner   => "root",
    group   => "root",
    require => File['/opt/custom/snmp'],
    mode    => '0755',
    source  => 'puppet:///modules/somehosttype/java_vm_used.sh',
  }

  ## Prefer that someday this is a secure filestore instead of puppet source tree
  file { "/opt/custom/someuser/conf/${cert_file}":
    ensure  => file,
    owner   => "someuser",
    group   => "someuser",
    mode    => "0640",
    require => [ User["someuser"], File["/opt/custom/someuser/conf"] ],
    source  => "puppet:///modules/somehosttype/${cert_file}",
  }

  ##### end CA cert

  cron { 'prune_files':
    command     => '/bin/find /var/ec/ -type f -mtime +7 -and ! -path "*_jsp*" -exec nice -n 10 rm {} \;',
    user        => "$application_user",
    hour        => 3,
    minute      => 0,
  } 

  cron { 'compress_files':
    command     => '/bin/find /var/ec/ -type f -mmin +120 -name "*log*" -and ! -name "*.gz" ! -name "jvm.log" -and ! -path "*_jsp*" -exec nice -n 10 gzip -9 {} \;',
    user        => "$application_user",
    hour        => 4,
    minute      => 0,
  } 

  cron { 'prune_packages':
    command   => '/usr/local/bin/ec-pkgclean.pl 4 2>&1'
    user      => 'root',
    minute    => 30,
    hour      => 3,
  }

  #working sysctl management taken from: http://docs.puppetlabs.com/guides/augeas.html#etcsysctlconf
  sysctl::conf {

  # vm.swappiness is a parameter which sets the kernel's balance
  # between reclaiming pages from the page cache and swapping
  # process memory. The default value is 60.
  "vm.swappiness": value =>  20;

  # Contains, as a percentage of total system memory, the number of
  # pages at which a process which is generating disk writes will
  # itself start writing out dirty data.  Set low due to extremely
  # large system memory.
  "vm.dirty_ratio": value =>  1;

  # Contains, as a percentage of total system memory, the number of
  # pages at which the pdflush background writeback daemon will
  # start writing out dirty data.  
  "vm.dirty_background_ratio": value =>  1;

  # increase max read/write buffer size that can be applied via setsockopt()
  "vm.vfs_cache_pressure": value =>  50;

  }


}

# vim: set et sta sts=4 sw=4 ts=8:
