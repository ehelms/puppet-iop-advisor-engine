# == Class: iop-advisor-engine
#
# Install and configure the advisor engine
#
# === Parameters:
#
# $image::  The container image
#
class iop_advisor_engine (
  String[1] $image = 'quay.io/evgeni/fake-iop-engine',
) {
  include podman
  include certs::iop_advisor_engine

  $service_name = 'iop-advisor-engine'
  $log_dir = "/var/log/${service_name}"

  $server_cert_secret_name = "${service_name}-server-cert"
  $server_key_secret_name = "${service_name}-server-key"
  $server_ca_cert_secret_name = "${service_name}-server-ca-cert"

  $client_cert_secret_name = "${service_name}-client-cert"
  $client_key_secret_name = "${service_name}-client-key"
  $client_ca_cert_secret_name = "${service_name}-client-ca-cert"

  $context = {
    'server_cert_secret_name'    => $server_cert_secret_name,
    'server_key_secret_name'     => $server_key_secret_name,
    'server_ca_cert_secret_name' => $server_ca_cert_secret_name,
    'client_cert_secret_name'    => $client_cert_secret_name,
    'client_key_secret_name'     => $client_key_secret_name,
    'client_ca_cert_secret_name' => $client_ca_cert_secret_name,
  }

  file { "/etc/containers/systemd/${service_name}.container.d":
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  file { "/etc/containers/systemd/${service_name}.container.d/10-certs.conf":
    ensure  => file,
    mode    => '0640',
    owner   => 'root',
    group   => 'root',
    content => epp('iop_advisor_engine/10-certs.conf.epp', $context),
    notify  => Podman::Quadlet[$service_name],
  }

  podman::secret { $server_cert_secret_name:
    path => $certs::iop_advisor_engine::server_cert,
  }

  podman::secret { $server_key_secret_name:
    path => $certs::iop_advisor_engine::server_key,
  }

  podman::secret { $server_ca_cert_secret_name:
    path => $certs::iop_advisor_engine::server_ca_cert,
  }

  podman::secret { $client_cert_secret_name:
    path => $certs::iop_advisor_engine::client_cert,
  }

  podman::secret { $client_key_secret_name:
    path => $certs::iop_advisor_engine::client_key,
  }

  podman::secret { $client_ca_cert_secret_name:
    path => $certs::iop_advisor_engine::client_ca_cert,
  }

  file { $log_dir:
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  ['uploads', 'failed', 'logs'].each |String $file| {
    file { "${log_dir}/${file}":
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }
  }

  podman::quadlet { $service_name:
    ensure       => 'present',
    quadlet_type => 'container',
    user         => 'root',
    defaults     => {},
    settings     => {
      'Unit'      => {
        'Description' => 'Advisor Engine',
      },
      'Container' => {
        'Image'   => $image,
        'Network' => 'host',
        'Volume'  => [
          "${log_dir}/uploads:/opt/app-root/src/uploads",
          "${log_dir}/failed:/opt/app-root/src/failed",
          "${log_dir}/logs:/opt/app-root/src/logs",
        ],
      },
      'Service'   => {
        'Restart' => 'always',
      },
      'Install'   => {
        'WantedBy' => 'default.target',
      },
    },
    require      => Podman::Secret[
      $server_cert_secret_name,
      $server_key_secret_name,
      $server_ca_cert_secret_name,
      $client_cert_secret_name,
      $client_key_secret_name,
      $client_ca_cert_secret_name
    ],
  }
}
