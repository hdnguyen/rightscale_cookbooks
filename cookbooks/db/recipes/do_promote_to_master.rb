#
# Cookbook Name:: db
#
# Copyright RightScale, Inc. All rights reserved.  All access and use subject to the
# RightScale Terms of Service available at http://www.rightscale.com/terms.php and,
# if applicable, other agreements such as a RightScale Master Subscription Agreement.

rightscale_marker :begin

DATA_DIR = node[:db][:data_dir]

# Verify initialized database
# Check the node state to verify that we have correctly initialized this server.
# See cookbooks/db/definitions/db_state_assert.rb for db_state_assert definition.
db_state_assert :slave

# Open port for slave replication by old-master
sys_firewall "Open port to the old master which is becoming a slave" do
  port node[:"#{node[:db][:provider]}"][:port].to_i
  enable true
  ip_addr node[:db][:current_master_ip]
  # See cookbooks/sys_firewall/providers/default.rb for update action.
  action :update
end

# Set mysql username and password with permissions to replicate from the new master.
# See cookbooks/db/recipes/setup_replication_privileges.rb
include_recipe "db::setup_replication_privileges"

# Promote to master
# Tags are not set here.  We need the tags on the old master in order
# to demote it later.  Once demoted, then we add master tags.
# See cookbooks/db_<provider>/providers/default.rb for promote action.
db DATA_DIR do
  action :promote
end

# Schedule backups on slave
# This should be done before calling db::do_lookup_master
# changes current_master from old to new.
remote_recipe "enable slave backups on oldmaster" do
  # See cookbooks/db/recipes/do_primary_backup_schedule_enable.rb
  recipe "db::do_primary_backup_schedule_enable"
  recipients_tags "rs_dbrepl:master_instance_uuid=#{node[:db][:current_master_uuid]}"
end

# Demote old master
remote_recipe "demote master" do
  # See cookbooks/db/recipes/handle_demote_master.rb
  recipe "db::handle_demote_master"
  attributes :remote_recipe => {
                :new_master_ip => node[:cloud][:private_ips][0],
                :new_master_uuid => node[:rightscale][:instance_uuid]
              }
  recipients_tags "rs_dbrepl:master_instance_uuid=#{node[:db][:current_master_uuid]}"
end

# Tag as master
# Changes master status tags and node state
# See cookbooks/db/definitions/db_register_master.rb for db_register_master definition.
db_register_master

# Setup collected to monitor for a master db
db DATA_DIR do
  # See cookbooks/db_<provider>/providers/default.rb for setup_monitoring action.
  action :setup_monitoring
end

# Perform a backup
# See cookbooks/db/definitions/db_request_backup.rb for db_request_backup definition.
db_request_backup "do backup"

# Schedule master backups
# See cookbooks/db/recipes/do_primary_backup_schedule_enable.rb
include_recipe "db::do_primary_backup_schedule_enable"

rightscale_marker :end
