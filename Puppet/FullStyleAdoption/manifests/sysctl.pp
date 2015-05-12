# Working sysctl management taken from: http://docs.puppetlabs.com/guides/augeas.html#etcsysctlconf

class sysctl {
   file { "sysctl_conf":
      name => $operatingsystem ? {
        default => "/etc/sysctl.conf",
      },
   }

   exec { "sysctl -p":
      alias       => "sysctl",
      refreshonly => true,
      subscribe   => File["sysctl_conf"],
   }
}