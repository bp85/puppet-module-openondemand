# @summary Manage Open OnDemand Apache
# @api private
class openondemand::apache {
  assert_private()

  if $openondemand::declare_apache {
    if $openondemand::scl_apache {
      class { '::apache::version':
        scl_httpd_version => '2.4',
        scl_php_version   => '7.0',
      }
    }
    class { '::apache':
      default_vhost => false,
    }
  } else {
    include ::apache
  }

  if $openondemand::scl_apache {
    $package_prefix = 'httpd24-'
  } else {
    $package_prefix = ''
  }

  include ::apache::mod::ssl
  ::apache::mod { 'session':
    package => "${package_prefix}mod_session",
  }
  ::apache::mod { 'session_cookie':
    package => "${package_prefix}mod_session",
  }
  ::apache::mod { 'session_dbd':
    package => "${package_prefix}mod_session",
  }
  ::apache::mod { 'auth_form':
    package => "${package_prefix}mod_session",
  }
  # mod_request needed by mod_auth_form - should probably be a default module.
  ::apache::mod { 'request': }
  # xml2enc and proxy_html work around apache::mod::proxy_html lack of package name parameter
  ::apache::mod { 'xml2enc':}
  ::apache::mod { 'proxy_html':
    package => "${package_prefix}mod_proxy_html",
  }
  include ::apache::mod::proxy
  include ::apache::mod::proxy_http
  include ::apache::mod::proxy_connect
  include ::apache::mod::proxy_wstunnel
  if $openondemand::auth_type == 'CAS' {
    include ::apache::mod::auth_cas
  }
  ::apache::mod { 'lua': }
  include ::apache::mod::headers

  case $openondemand::auth_type {
    'CAS': {
      include ::apache::mod::auth_cas
    }
    '(dex|openid-connect)': {
      ::apache::mod { 'auth_openidc':
        package        => "${package_prefix}mod_auth_openidc",
        package_ensure => $openondemand::mod_auth_openidc_ensure,
      }
    }
    'mellon': {
      ::apache::mod { 'auth_mellon':
        package        => "${package_prefix}mod_auth_mellon",
        package_ensure => $openondemand::mod_auth_openidc_ensure,
      }
    }
    default: {}
  }

  if $openondemand::scl_apache {
    shellvar { 'HTTPD24_HTTPD_SCLS_ENABLED':
      ensure  => 'present',
      target  => '/opt/rh/httpd24/service-environment',
      value   => $openondemand::apache_scls,
      require => Package['httpd'],
      notify  => Class['Apache::Service'],
    }
  }

  systemd::dropin_file { 'ood.conf':
    unit    => "${::apache::service_name}.service",
    content => join([
      '[Service]',
      'KillSignal=SIGTERM',
      'KillMode=process',
      'PrivateTmp=false',
      '',
    ], "\n"),
    notify  => Class['::apache::service'],
  }
  systemd::dropin_file { 'ood-portal.conf':
    ensure => 'absent',
    unit   => "${::apache::service_name}.service",
    notify => Class['::apache::service'],
  }
}
