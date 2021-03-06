#
# Cookbook:: my_a2
# Recipe:: default
#
# Copyright:: 2019, The Authors, All Rights Reserved.

# we may need a proxy to download the bundle components
# unless node['ma2']['aib']['proxy'].nil?
#   ENV['HTTP_PROXY'] = ENV['HTTPS_PROXY'] = ENV['http_proxy'] = ENV['https_proxy'] = node['ma2']['aib']['proxy']
# end

# use private CA bundle for remote files if defined
# unless node['cacerts'].nil?
#   cookbook_file 'Install private CA certificates' do
#     path node['cacerts']
#     source 'private-cacert.pem'
#     sensitive true
#     mode '0644'
#   end
#   ENV['SSL_CERT_FILE'] = node['cacerts']
# end

include_recipe 'my_a2::prereqs'
include_recipe 'managed-automate2::airgap_bundle'
include_recipe 'managed-automate2::default'
