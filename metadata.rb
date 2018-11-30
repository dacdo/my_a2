name             'my_a2'
maintainer       'Dac Do'
maintainer_email 'dac.do@fastlane-it.com'
license          'all_rights'
description      'Installs/Configures my_a2'
long_description 'Installs/Configures my_a2'
version          '0.1.0'

chef_version     '> 13.0' if respond_to?(:chef_version)
supports         'redhat'
supports         'centos'

depends          'managed-automate2', '~> 0.6'
