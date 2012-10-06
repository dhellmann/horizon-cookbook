#
# Cookbook Name:: horizon
# Recipe:: server
#
# Copyright 2012, DreamHost
#
# All rights reserved - Do Not Redistribute
#

include_recipe "apache2"
include_recipe "apache2::mod_wsgi"
include_recipe "apache2::mod_rewrite"
include_recipe "apache2::mod_ssl"
include_recipe "mysql::ruby"
include_recipe "osops-utils"
include_recipe "osops-utils::repo"

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

ks_admin_endpoint = get_access_endpoint("keystone", "keystone", "admin-api")
ks_service_endpoint = get_access_endpoint("keystone", "keystone","service-api")
keystone = get_settings_by_role("keystone", "keystone")

# Allow for using a well known db password
if node["developer_mode"]
  node.set_unless["openstack"]["horizon"]["db"]["password"] = "horizon"
else
  node.set_unless["openstack"]["horizon"]["db"]["password"] = secure_password
end

#creates db and user
#function defined in osops-utils/libraries
create_db_and_user("mysql",
                   node["openstack"]["horizon"]["db"]["name"],
                   node["openstack"]["horizon"]["db"]["username"],
                   node["openstack"]["horizon"]["db"]["password"])

package "openstack-dashboard" do
    action :upgrade
end

directory "#{node["openstack"]["horizon"]["dash_path"]}/.blackhole" do
    action :create
end

package "python-mysqldb" do
    action :install
end

package "node-less" do
    action :install
end

template "/etc/openstack-dashboard/local_settings.py" do
  source "local_settings.py.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
            :user => node["openstack"]["horizon"]["db"]["username"],
            :passwd => node["openstack"]["horizon"]["db"]["password"],
            :ip_address => IPManagement.get_access_ip_for_role("keystone", "management", node),
            :db_name => node["openstack"]["horizon"]["db"]["name"],
            :db_host => IPManagement.get_access_ip_for_role("mysql-master", "management", node),
            :service_port => ks_service_endpoint["port"],
            :admin_port => ks_admin_endpoint["port"],
            :admin_token => keystone["admin_token"]
  )
end

execute "openstack-dashboard syncdb" do
  cwd "/usr/share/openstack-dashboard"
  environment ({'PYTHONPATH' => '/etc/openstack-dashboard:/usr/share/openstack-dashboard:$PYTHONPATH'})
  command "python manage.py syncdb"
  action :run
  # not_if "/usr/bin/mysql -u root -e 'describe #{node["dash"][:db]}.django_content_type'"
end

template value_for_platform(
  [ "redhat", "centos" ] => { "default" => "#{node[:apache][:dir]}/vhost.d/openstack-dashboard" },
  [ "ubuntu","debian" ] => { "default" => "#{node[:apache][:dir]}/sites-available/openstack-dashboard" },
  "default" => { "default" => "#{node[:apache][:dir]}/openstack-dashboard" }
  ) do
  source "dash-site.erb"
  owner "root"
  group "root"
  mode "0644"
  variables(
      :apache_contact => node[:apache][:contact],
      :ssl_cert_file => "#{node[:apache][:cert_dir]}certs/#{node[:apache][:self_cert]}",
      :ssl_key_file => "#{node[:apache][:cert_dir]}private/#{node[:apache][:self_cert_key]}",
      :apache_log_dir => node[:apache][:log_dir],
      :django_wsgi_path => "#{node["openstack"]["horizon"]["wsgi_path"]}",
      :dash_path => "#{node["openstack"]["horizon"]["dash_path"]}"
  )
end

if platform?("debian", "ubuntu") then
  apache_site "openstack-dashboard"
end

# This is a dirty hack to deal with https://bugs.launchpad.net/nova/+bug/932468
directory "/var/www/.novaclient" do
  owner node[:apache][:user]
  group node[:apache][:group]
  mode "0755"
  action :create
end

# TODO(shep)
# Horizon has a forced dependency on their being a volume service endpoint in your keystone catalog
# https://answers.launchpad.net/horizon/+question/189551

service "apache2" do
   action :restart
end
