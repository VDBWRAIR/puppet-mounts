# Define mounts

define mounts (
  $source = undef,
  $dest   = undef,
  $type   = undef,
  $opts   = 'defaults',
  $dump   = 0,
  $passno = 0,
  $ensure = 'present'){

  if $source == undef {
    err('The source parameter is required.')
  }

  if $dest == undef {
    err('The dest parameter is required.')
  }

  if $type == undef {
    err('The type parameter is required.')
  }

  case $::operatingsystem {
    redhat, centos, amazon: {

      if $opts =~ 'krb' {
          if empty($klist) {
              notify { "Mount point ${source} requires kerberos and does not have a klist entry to support it": }
              $canmount = false
          } else {
              $canmount = true
          }
      } else {
        $canmount = true
      }

      if $canmount {
          fstab { "fstab entry for ${source} to ${dest} as ${type}":
            ensure => $ensure,
            source => $source,
            dest   => $dest,
            type   => $type,
            opts   => $opts,
            dump   => $dump,
            passno => $passno,
          }
      }

      if $type == 'nfs' {
        ensure_resource('package', 'nfs-utils', {'ensure' => 'latest','require' => undef})
        case $::operatingsystemmajrelease {
          '6': {
            ensure_resource('package', 'rpcbind', {'ensure' => 'present','require' => undef})
            ensure_resource('service', 'rpcbind', {'ensure' => 'running', 'require' => undef})
            Package['rpcbind'] -> Service['rpcbind']
          }
          '5': {
            ensure_resource('package', 'portmap', {'ensure' => 'present'})
            ensure_resource('service', 'portmap', {'ensure' => 'running'})
            Package['portmap'] -> Service['portmap']
          }
          default: {
            alert('Unsupported version of OS')
          }
        }
      }
      if $type == 'cifs' {
        ensure_resource('package', 'cifs-utils', {'ensure' => 'present'})
      }

      case $ensure {
        'present': {
          # Ensure the entire tree of the destination has been created.
          $dirtree = dirtree($dest)
          ensure_resource('file', $dirtree, {'ensure' => 'directory'})

          if $canmount {
            exec { "/bin/mount '${dest}'":
              unless  => "/bin/mount -l | /bin/grep '${dest}'",
              require => [File[$dirtree], Fstab["fstab entry for ${source} to ${dest} as ${type}"]],
            }
          }
        }
        'absent': {
          exec { "/bin/umount '${dest}'":
            onlyif => "/bin/mount -l | /bin/grep '${dest}'",
            before => Fstab["fstab entry for ${source} to ${dest} as ${type}"],
          }

          # Note: we won't remove the directory since we don't know if it'll destroy data
          notify { "${dest} wasn't removed after being unmounted.  Please remove it manually.": }
        }
        default: { }
      }
    }
    default: { err('Your OS isn\'t supported by the mounts module yet.') }
  }

}
