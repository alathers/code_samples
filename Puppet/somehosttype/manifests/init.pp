# = Class: somehosttype
#
# The somehosttype class was spawned as a dupe of the legacyhosttype module.  From there most of the repeat work
# has been stubbed out into other classes for common work (java install, encryption key files etc
#
# Below tasks are:
# - add someuser user
# - deploy some snmp test scripts (legacy, unsure of consumer of these)
# - create some basic filesystem paths needed by packages and other dependancies (this may cause conflicts
#          with the modules I broke out of the legacyhosttype class
# - deploy the crontab files for log management
# - implement some sysctl parameters (mostly related to virtual memory management)
#
#
# === Parameters
#
# $cert_file = if not set, is hard set to intermediate-CA.cer to deploy to /opt/ec/someuser/conf
#
#
# === Authors
#
# Adam Lathers 
#
# === License
#
# License: This is for inspection only, no re-use allowed without written consent from author.
#

class somehosttype {
    # === someuser stuff
    realize (
        Group["someuser"],
        User["someuser"],
    )

    # lock his account
    exec { "passwd -l someuser":
        path    => "/bin:/usr/bin",
        unless  => "grep '^someuser:!!' /etc/shadow",
        require => User["someuser"],
    }

# deploy snmp script to verify access to external SaaS provider.  as of 1/7/2012, it fetches this URL https://somesite.com/some/path
    file { '/opt/ec/snmp/bin/cybersource_test':
        ensure  => present,
        require => File['/opt/ec/snmp'],
        mode => '0555',
        source  => 'puppet:///modules/someothermodule/saasVendor_test',
    }

# SNMP report to describe present largest JavaVM footprint.  Might not be appropriate for somehosttype, only legacyhosttype?
# collects largest from call to "ps -C java -o vsize --sort vsize"
    file { '/opt/ec/snmp/bin/java_vm_used.sh':
        ensure  => present,
        owner   => "root",
        group   => "root",
        require => File['/opt/ec/snmp'],
        mode    => '0755',
        source  => 'puppet:///modules/somehosttype/java_vm_used.sh',
    }

#Create basic filesystem paths since they are likely not properly created by packages
    file { "/opt/ec/someuser":
        ensure => directory,
        owner  => "root",
        group  => "root",
        mode   => "0755",
    }

    file { "/opt/ec/someuser/conf":
        ensure  => directory,
        owner   => "someuser",
        group   => "someuser",
        mode    => "0755",
        require => [ User["someuser"], File["/opt/ec/someuser"] ]
    }

    file { "/var/ec":
        owner   => "someuser",
        group   => "someuser",
        mode    => "0755",
        require => [ User["someuser"] ],
    }
#### END Create paths

# Set default value for CA cert to be deployed as below
### This is likely candidate to be stubbed out into something else, but purpose/justifacation is unclear.
    if !$cert_file {
        $cert_file = "intermediate-CA.cer"
    }

## Prefer that someday this is a secure filestore instead of puppet source tree
    file { "/opt/ec/someuser/conf/${cert_file}":
        ensure  => file,
        owner   => "someuser",
        group   => "someuser",
        mode    => "0640",
        require => [ User["someuser"], File["/opt/ec/someuser/conf"] ],
        source  => "puppet:///modules/somehosttype/${cert_file}",
    }

##### end CA cert

# Deploy crontab file
    file { "/etc/cron.d/somehosttype":
        owner   => "root",
        group   => "root",
        mode    => 644,
        ensure  => file,
        source  => "puppet:///modules/somehosttype/etc_cron.d_somehosttype",
    }

    # === Add someuser sysctls

    # Contains, as a percentage of total system memory, the number of
    # pages at which a process which is generating disk writes will
    # itself start writing out dirty data.  Set low due to extremely
    # large system memory.
    ensure_value { "someuser sysctl 1":
        file  => "/etc/sysctl.conf",
        key   => "vm.dirty_ratio",
        value => "1",
    }

    # Contains, as a percentage of total system memory, the number of
    # pages at which the pdflush background writeback daemon will
    # start writing out dirty data.
    ensure_value { "someuser sysctl 2":
        file  => "/etc/sysctl.conf",
        key   => "vm.dirty_background_ratio",
        value => "1",
    }

    # Controls the tendency of the kernel to reclaim the memory which
    # is used for caching of directory and inode objects.  Present
    # value makes it "avoid" reclaiming.
    ensure_value { "someuser sysctl 3":
        file  => "/etc/sysctl.conf",
        key   => "vm.vfs_cache_pressure",
        value => "50",
    }

    # vm.swappiness is a parameter which sets the kernel's balance
    # between reclaiming pages from the page cache and swapping
    # process memory. The default value is 60.
    ensure_value { "someuser sysctl 4":
        file  => "/etc/sysctl.conf",
        key   => "vm.swappiness",
        value => "20",
    }
 
}


# vim: set et sta sts=4 sw=4 ts=8:
