default['cacerts'] = nil

# Chef Automate install ZIP file source
# default['ma2']['aib']['zip'] = 'https://packages.chef.io/files/current/latest/chef-automate-cli/chef-automate_linux_amd64.zip'

# (expected) name of the installer binary in the ZIP
default['ma2']['aib']['installer'] = 'chef-automate'
default['ma2']['aib']['file'] = 'aib-file'

# Internal web proxy for downloading bundle components from chef sites.
# If nil then no proxy is set and a direct connection is assumed.
#
# default['ma2']['aib']['proxy'] = 'http://10.157.10.4:8080'

# resulting airgap bundle name prefix as delivered
# default['ma2']['aib']['name'] = 'chef-automate-airgap'

# where to lodge the airgap bundle after building
# default['ma2']['aib']['dir'] = '/tmp/aibundle'
