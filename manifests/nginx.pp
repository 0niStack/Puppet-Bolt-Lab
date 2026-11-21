# Lesson: package + file + service, plus facts (OS family) and ordering.
$docroot = $facts['os']['family'] ? {
  'RedHat' => '/usr/share/nginx/html',
  default  => '/var/www/html',
}

package { 'nginx':
  ensure => installed,
}

file { "${docroot}/index.html":
  ensure  => file,
  content => "<h1>NGINX server</h1><p>Host: ${facts['networking']['hostname']}</p><p>Managed by Puppet Bolt</p>\n",
  require => Package['nginx'],
  notify  => Service['nginx'],
}

service { 'nginx':
  ensure  => running,
  enable  => true,
  require => Package['nginx'],
}
