# Lesson: same idea as nginx.pp, but package/service names differ per OS family.
$apache = $facts['os']['family'] ? {
  'RedHat' => 'httpd',
  default  => 'apache2',
}

package { $apache:
  ensure => installed,
}

file { '/var/www/html/index.html':
  ensure  => file,
  content => "<h1>Apache server</h1><p>Host: ${facts['networking']['hostname']}</p><p>Managed by Puppet Bolt</p>\n",
  require => Package[$apache],
  notify  => Service[$apache],
}

service { $apache:
  ensure  => running,
  enable  => true,
  require => Package[$apache],
}
