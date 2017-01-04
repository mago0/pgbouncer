#
# Cookbook Name:: pgbouncer
# Provider:: connection
#
# Copyright 2010-2013, Whitepages Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

def initialize(*args)
  super
  @action = :setup
end

action :start do
  service "pgbouncer-#{new_resource.db_alias}-start" do
    service_name "pgbouncer-#{new_resource.db_alias}" # this is to eliminate warnings around http://tickets.opscode.com/browse/CHEF-3694
    provider Chef::Provider::Service::Upstart
    action [:enable, :start]
  end
end

action :restart do
  service "pgbouncer-#{new_resource.db_alias}-restart" do
    service_name "pgbouncer-#{new_resource.db_alias}" # this is to eliminate warnings around http://tickets.opscode.com/browse/CHEF-3694
    provider Chef::Provider::Service::Upstart
    action [:enable, :restart]
  end
end

action :stop do
  service "pgbouncer-#{new_resource.db_alias}-stop" do
    service_name "pgbouncer-#{new_resource.db_alias}" # this is to eliminate warnings around http://tickets.opscode.com/browse/CHEF-3694
    provider Chef::Provider::Service::Upstart
    action :stop
  end
end

action :setup do

  group new_resource.group do

  end

  user new_resource.user do
    gid new_resource.group
    system true
  end

  # install the pgbouncer package
  #
  package 'pgbouncer' do
    action [:install]
    options '-o Dpkg::Options::="--force-confold"'
  end

  # Stop the default init.d service as installed by the package
  service "pgbouncer" do
    supports :stop => true, :disable => true
    action [:stop, :disable]
  end

  # Delete the default package configs
  file "/etc/pgbouncer/pgbouncer.ini" do
    action :delete
  end
  file "/etc/pgbouncer/userlist.txt" do
    action :delete
  end

  service "pgbouncer-#{new_resource.db_alias}" do
    provider Chef::Provider::Service::Upstart
    supports :enable => true, :start => true, :restart => true
    action :nothing
  end

  # create the log, pid, db_sockets, /etc/pgbouncer, and application socket directories
  [
   new_resource.log_dir,
   new_resource.pid_dir,
   new_resource.socket_dir,
   ::File.expand_path(::File.join(new_resource.socket_dir, new_resource.db_alias)),
   '/etc/pgbouncer'
  ].each do |dir|
    directory dir do
      action :create
      recursive true
      owner new_resource.user
      group new_resource.group
      mode 0775
    end
  end

  template "/etc/pgbouncer/userlist-#{new_resource.db_alias}.txt" do
    cookbook 'pgbouncer'
    source 'etc/pgbouncer/userlist.txt.erb'
    owner new_resource.user
    group new_resource.group
    mode 0640
    notifies :restart, "service[pgbouncer-#{new_resource.db_alias}]"
    variables(
      userlist: new_resource.userlist
    )
  end

  # build the pgbouncer.ini, upstart conf and logrotate.d templates
  {
    "/etc/pgbouncer/pgbouncer-#{new_resource.db_alias}.ini" => 'etc/pgbouncer/pgbouncer.ini.erb',
    "/etc/init/pgbouncer-#{new_resource.db_alias}.conf" => 'etc/init/pgbouncer.conf.erb',
    "/etc/logrotate.d/pgbouncer-#{new_resource.db_alias}" => 'etc/logrotate.d/pgbouncer-logrotate.d.erb'
  }.each do |key, source_template|
    ## We are setting destination_file to a duplicate of key because the hash
    ## key is frozen and immutable.
    destination_file = key.dup

    template_variables = {
        user: new_resource.user,
        pid_dir: new_resource.pid_dir,
        db_alias: new_resource.db_alias,
        db_host: new_resource.db_host,
        db_port: new_resource.db_port,
        db_name: new_resource.db_name,
        connect_query: new_resource.connect_query,
        log_dir: new_resource.log_dir,
        listen_addr: new_resource.listen_addr,
        listen_port: new_resource.listen_port,
        socket_dir: new_resource.socket_dir,
        pool_mode: new_resource.pool_mode,
        server_reset_query: new_resource.server_reset_query,
        server_check_delay: new_resource.server_check_delay,
        max_client_conn: new_resource.max_client_conn,
        default_pool_size: new_resource.default_pool_size,
        min_pool_size: new_resource.min_pool_size,
        reserve_pool_size: new_resource.reserve_pool_size,
        reserve_pool_timeout: new_resource.reserve_pool_timeout,
        server_round_robin: new_resource.server_round_robin,
        server_idle_timeout: new_resource.server_idle_timeout,
    }
    unless new_resource.tcp_keepalive.nil?
      template_variables[:tcp_keepalive] = new_resource.tcp_keepalive
    end
    unless new_resource.tcp_keepidle.nil?
      template_variables[:tcp_keepidle] = new_resource.tcp_keepidle
    end
    unless new_resource.tcp_keepintvl.nil?
      template_variables[:tcp_keepintvl] = new_resource.tcp_keepintvl
    end

    template destination_file do
      cookbook 'pgbouncer'
      source source_template
      owner new_resource.user
      group new_resource.group
      mode 0644
      notifies :restart, "service[pgbouncer-#{new_resource.db_alias}]"
      variables(template_variables)
    end
  end

  new_resource.updated_by_last_action(true)
end

action :teardown do

  { "/etc/pgbouncer/userlist-#{new_resource.db_alias}.txt" => 'etc/pgbouncer/userlist.txt.erb',
    "/etc/pgbouncer/pgbouncer-#{new_resource.db_alias}.ini" => 'etc/pgbouncer/pgbouncer.ini.erb',
    "/etc/init/pgbouncer-#{new_resource.db_alias}.conf" => 'etc/pgbouncer/pgbouncer.conf',
    "/etc/logrotate.d/pgbouncer-#{new_resource.db_alias}" => 'etc/logrotate.d/pgbouncer-logrotate.d'
  }.each do |destination_file, source_template|
    file destination_file do
      action :delete
    end
  end

  new_resource.updated_by_last_action(true)
end
