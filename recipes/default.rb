#
# Cookbook Name:: my_a2
# Recipe:: default

include_recipe 'my_a2::configure'
include_recipe 'managed-automate2::airgap_bundle'
#include_recipe 'managed-automate2::default'
