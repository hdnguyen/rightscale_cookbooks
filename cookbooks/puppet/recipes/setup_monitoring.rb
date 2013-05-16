#
# Cookbook Name:: puppet
#
# Copyright RightScale, Inc. All rights reserved.
# All access and use subject to the RightScale Terms of Service available at
# http://www.rightscale.com/terms.php and, if applicable, other agreements
# such as a RightScale Master Subscription Agreement.

rightscale_marker :begin

# Creates the collectd plugin directory.
directory "#{node[:rightscale][:collectd_lib]}/plugins/" do
  recursive true
  not_if { ::File.exists?("#{node[:rightscale][:collectd_lib]}/plugins/") }
end

# Creates the collectd plugin for the Puppet Client stats collection.
template "#{node[:rightscale][:collectd_lib]}/plugins/puppet-stats.sh" do
  mode "0755"
  backup false
  source "collectd_puppet_client_stats.erb"
  cookbook "puppet"
end

service "collectd" do
  action :nothing
end

# Creates the collectd conf file for the Puppet Client monitoring.
template "#{node[:rightscale][:collectd_plugin_dir]}/puppet-client.conf" do
  mode "0644"
  source "collectd_puppet_client.erb"
  cookbook "puppet"
  backup false
  variables(
    :stats => "#{node[:rightscale][:collectd_lib]}/plugins/puppet-stats.sh"
  )
  notifies :restart, resources(:service => "collectd")
end

rightscale_marker :end
