#
# Cookbook Name:: my_a2
# Recipe:: configure

chefautomate = node['ma2']['aib']['dir'] + '/chef-automate'
installfile = node['ma2']['aib']['dir'] + '/' + node['ma2']['aib']['file']

package 'tree'

cookbook_file chefautomate do
  source 'chef-automate'
  action :create
end

cookbook_file installfile do
  source node['ma2']['aib']['file']
  action :create
end
