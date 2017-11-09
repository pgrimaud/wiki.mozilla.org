class { 'apt':
}

$varnish_exporter_version = '1.3.4'
$varnish_exporter_url = "https://github.com/jonnenauha/prometheus_varnish_exporter/releases/download/${varnish_exporter_version}/prometheus_varnish_exporter-${varnish_exporter_version}.linux-amd64.tar.gz"

Exec['apt_update'] -> Package['varnish']
Class['apache'] -> Class['varnish']

class {'varnish':
  varnish_listen_port  => 80,
  varnish_storage_size => '2G',
  version              => '4.1',
}

class {'varnish::ncsa':
}

class { 'varnish::vcl':
  backends               => {}, # without this line you will not be able to redefine backend 'default'
  cookiekeeps            => [
    'wiki_session',
    'wikiUserID',
  ],
  logrealip              => true,
  honor_backend_ttl      => true,
  cond_requests          => true,
  https_redirect         => true,
  x_forwarded_proto      => true,
  pipe_uploads           => true,
  purgeips               => [ '127.0.0.1' ],
  unset_headers          => [],
  unset_headers_debugips => [],
  cond_unset_cookies     => '
    # Static file cache
    req.url ~ "(?i)\.(jpg|jpeg|gif|png|tiff|tif|svg|swf|ico|css|kss|js|vsd|doc|ppt|pps|xls|pdf|mp3|mp4|m4a|ogg|mov|avi|wmv|sxw|zip|gz|bz2|tar|rar|odc|odb|odf|odg|odi|odp|ods|odt|sxc|sxd|sxi|sxw|dmg|torrent|deb|msi|iso|rpm|jar|class|flv|exe)($|\?)" ||
    req.url ~ "^(?i)/load.php"
',
}

varnish::probe {  'mediawiki_version':
  url     => '/Special%3AVersion',
  timeout => '15s',
}

varnish::backend { 'default':
  host  => '127.0.0.1',
  port  => '81',
  probe => 'mediawiki_version',
}

notice ("Grabbing varnish_exporter ${varnish_exporter_version}")
staging::file { "varnish_exporter.${varnish_exporter_version}.tar.gz":
  source => $varnish_exporter_url,
}
->staging::extract { "varnish_exporter.${varnish_exporter_version}.tar.gz":
  target  => '/usr/local/bin',
  strip   => 1,
  creates => '/usr/local/bin/prometheus_varnish_exporter',
}

include nubis_discovery

nubis::discovery::service { 'varnish':
  tcp      => 80,
  interval => '15s',
}

upstart::job { 'varnish_exporter':
    description    => 'Prometheus Varnish Exporter',
    service_ensure => 'stopped',
    service_enable => true,
    # Never give up
    respawn        => true,
    respawn_limit  => 'unlimited',
    start_on       => '(local-filesystems and net-device-up IFACE!=lo)',
    user           => 'root',
    group          => 'root',
    exec           => '/usr/local/bin/prometheus_varnish_exporter',
}
