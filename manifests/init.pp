class pe-upgrade (
    $pe_version
  ) {
  #$pe_version = '3.7.0'
  #$platform = "solaris-10-sparc"

  notify {"pe_version is ${pe_version}..":}
  if $pe_version == undef {
    fail("pe_version cannot be empty!")
  }

  #validate_string($pe_version)

  # Note that in the case of solaris, this is not really a module. The original code
  # provided in a bootstrap session did provide a true module. However, once the
  # module code was started on a solaris host, one of the early tasks was to shut
  # down the puppet agent. This, in turn, killed and reaped the upgrade process.
  # The work around is to setup a shell script to run as an 'at' job 3 minutes in
  # the future. This allows the catalog run to finish gracefully and then the script
  # controls the upgrade process and can shut down the agent without consequences.
  case $::osfamily {
    'Solaris': {
      notify {"Installing PE Agent ${pe_version} for Solaris family...":}

      if $::kernelrelease != "5.10" {
        fail("Solaris version is not 5.10!")
      }
       
      file {"/tmp/puppet-enterprise-${pe_version}-solaris-10-sparc.tar.gz":
        source =>"puppet:///solaris/puppet-enterprise-${pe_version}-solaris-10-sparc.tar.gz",
        ensure => present,
      } ->
      exec {"/usr/bin/gunzip -dc puppet-enterprise-${pe_version}-solaris-10-sparc.tar.gz | /usr/bin/tar xf - ":
        cwd    => '/tmp',
        unless => "/usr/bin/test -d /tmp/puppet-enterprise-${pe_version}-solaris-10-sparc",
      } ->
      file {"/tmp/puppet-enterprise-${pe_version}-solaris-10-sparc/agupgrade":
        content => "/usr/bin/touch /tmp/puppet-enterprise-${pe_version}-solaris-10-sparc/AlreadyRan\n/usr/bin/echo \"Beginning upgrade of puppet software on ${hostname} from ${puppetversion} to ${pe_version}.\" | /usr/bin/mail -s \"Puppet Upgrade Notice ${hostname}\" philip.moors@fda.hhs.gov,daren.arnold@fda.hhs.gov\n/tmp/puppet-enterprise-${pe_version}-solaris-10-sparc/puppet-enterprise-installer -a /tmp/answers.upgrade -l /var/tmp/puppet-install-${pe_version}.log\nsleep 30\n/usr/bin/echo 'shutting down mcollective' >> /var/tmp/puppet-install-${pe_version}.log\n/usr/bin/svcadm disable pe-mcollective\nsleep 10\n/usr/bin/echo 'starting up mcollective' >> /var/tmp/puppet-install-${pe_version}.log\n/usr/bin/svcadm enable pe-mcollective\n/usr/bin/mail -s \"Completed Puppet Upgrade on host ${hostname} ${pe_version}.\" philip.moors@fda.hhs.gov,daren.arnold@fda.hhs.gov < /var/tmp/puppet-install-${pe_version}.log",
        owner => 'root',
        group => 'root',
        mode => '0644',
        ensure => file,
      } ->
      file {"/tmp/answers.upgrade":
        content => "q_install=Y",
        ensure => file,
      } ->
      exec {"/usr/bin/cat /tmp/puppet-enterprise-${pe_version}-solaris-10-sparc/agupgrade | /usr/bin/at now + 3 minutes":
        unless => "/usr/bin/test -f /tmp/puppet-enterprise-${pe_version}-solaris-10-sparc/AlreadyRan",
      }
    }
    'RedHat': {
      notify {"Installing PE Agent ${pe_version} for RedHat family...":}

      $pe_master  = $::settings::server
      $platform   = "el-${::operatingsystemmajrelease}-${::architecture}"
 
      notify {"Accessing https://${pe_master}:8140/packages/puppet-enterprise-${pe_version}-${platform}-agent/agent_packages/${platform}/...":}

      yumrepo { 'pe-agent':
        baseurl   => "https://${pe_master}:8140/packages/puppet-enterprise-${pe_version}-${platform}-agent/agent_packages/${platform}/",
        descr     => 'Puppet Labs PE Agent',
        enabled   => '1',
        gpgcheck  => '1',
        gpgkey   => "https://${pe_master}:8140/packages/GPG-KEY-puppetlabs",
        notify => Service['pe-mcollective'],
        sslverify => "false",
      }~>
 
      package { 'pe-agent':
        ensure => 'latest',
      }

  service { 'pe-puppet':
      ensure => running,
      enable => true,
      subscribe => Yumrepo ['pe-agent'],
  }
    }
  }


}
