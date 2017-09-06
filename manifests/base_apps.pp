# This is a set of applications that you will want on most systems
#
# Services this class manages:
#   * irqbalance (enabled by default by vendor)
#   * netlabel   (not installed by vendor)
#
#   On EL 6:
#     * haldaemon   (enabled by defauly by vendor)
#     * portreserve (disabled by default by vendor)
#     * quota_nld   (stopped by deafult by vendor)
#
# @param ensure
#   The ``$ensure`` status of all of the included packages
#
#   * Version pinning is not supported
#   * If you need version pinning, do not include this class
#
# @param extra_apps
#   A list of other applications that you wish to install
#
# @param manage_elinks_config
#   Add some useful settings to the global elinks configuration
#
# @author Trevor Vaughan <tvaughan@onyxpoint.com>
#
class simp::base_apps (
  Simp::PackageEnsure       $ensure               = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  Optional[Array[String,1]] $extra_apps           = undef,
  Boolean                   $manage_elinks_config = true
) {

  if $facts['os']['name'] in ['RedHat','CentOS'] {
    $_elinks_conf = '/etc/elinks.conf'
    $core_apps = [
      'dos2unix',
      'elinks',
      'hunspell',
      'lsof',
      'man',
      'man-pages',
      'mlocate',
      'pax',
      'pinfo',
      'sos',
      'star',
      'symlinks',
      'vim-enhanced',
      'words',
      'x86info',
      'irqbalance',
      'netlabel_tools',
      'bind-utils'
    ]
  }
  elsif $facts['os']['name'] in ['Debian','Ubuntu'] {
    $_elinks_conf = '/etc/elinks/elinks.conf'
    $core_apps = [
      'dnsutils',
      'bind9-host',
      'bridge-utils',
      'dos2unix',
      'elinks',
      'hunspell',
      'lsof',
      'man-db',
      'manpages',
      'mlocate',
      'pax',
      'pinfo',
      'sosreport',
      # 'star', not available from Debian repositories
      'symlinks',
      'vim',
      'wamerican',
      'x86info',
      'irqbalance'
    ]
  }
  else {
    fail("OS '${facts['os']['name']}' not supported by '${module_name}'")
  }
  $apps = $extra_apps ? {
    Array   => $core_apps + $extra_apps,
    default => $core_apps
  }
  package { $apps: ensure => $ensure }

  service { 'irqbalance':
    enable     => true,
    hasrestart => true,
    hasstatus  => false,
    require    => Package['irqbalance']
  }
  if $facts['os']['name'] in ['RedHat','CentOS'] {
    service { 'netlabel':
      ensure     => 'running',
      enable     => true,
      hasrestart => true,
      hasstatus  => true,
      require    => Package['netlabel_tools']
    }
  }

  case $facts['os']['name'] {
    'RedHat','CentOS': {
      if $facts['os']['release']['major'] > '6' {
        # For now, these will be commented out and ignored by svckill
        # Puppet cannot enable these services because there is no
        # init.d script or systemd script to do so.

        # service { 'quotaon': enable => true }
        # service { 'messagebus': enable  => true }
        svckill::ignore { 'quotaon': }
        svckill::ignore { 'messagebus': }
      }
      else {
        package { ['hal', 'quota']: ensure => $ensure }
        service { 'haldaemon':
          ensure     => 'running',
          enable     => true,
          hasrestart => true,
          hasstatus  => true,
          require    => Package['hal']
        }

        # portreserve will only start if there is a file in the conf directory
        if $facts['portreserve_configured'] {
          package { 'portreserve':
            ensure => $ensure
          }

          service { 'portreserve':
            ensure     => 'running',
            enable     => true,
            hasrestart => true,
            hasstatus  => false
          }
        }

        service { 'quota_nld':
          ensure     => 'running',
          enable     => true,
          hasrestart => true,
          hasstatus  => true,
          require    => Package['quota']
        }
      }
    }
    'Debian','Ubuntu': {
      package { 'quota': ensure => $ensure }

      svckill::ignore { 'acpid': }
      svckill::ignore { 'bootlogs': }
      svckill::ignore { 'console-setup': }
      svckill::ignore { 'dbus': }
      svckill::ignore { 'getty@': }
      svckill::ignore { 'hwclock-save': }
      svckill::ignore { 'kbd': }
      svckill::ignore { 'keyboard-setup': }
      svckill::ignore { 'kmod': }
      svckill::ignore { 'motd': }
      svckill::ignore { 'networking': }
      svckill::ignore { 'procps': }
      svckill::ignore { 'quota': }
      svckill::ignore { 'quotarpc': }
      svckill::ignore { 'rc.local': }
      svckill::ignore { 'restorecond': }
      svckill::ignore { 'rmnologin': }
      svckill::ignore { 'selinux-basics': }
      svckill::ignore { 'udev': }
      svckill::ignore { 'udev-finish': }
      svckill::ignore { 'urandom': }
    }
    default: {
      fail("${facts['os']['name']} is not yet supported by ${module_name}")
    }
  }

  if $manage_elinks_config {
    file { $_elinks_conf:
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      require => Package['elinks']
    }

    file_line { 'elinks_ui_lang':
      path    => $_elinks_conf,
      line    => 'set ui.language = "System"',
      require => File[$_elinks_conf]
    }

    file_line { 'elinks_css_disable':
      path    => $_elinks_conf,
      line    => 'set document.css.enable = 0',
      require => File[$_elinks_conf]
    }
  }
}
