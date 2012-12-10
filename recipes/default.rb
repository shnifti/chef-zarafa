#
# Cookbook Name:: zarafa
# Recipe:: default
#
# Copyright 2012, computerlyrik
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


#TODO
#wget http://download.zarafa.com/community/final/7.0/7.0.8-35178/zcp-7.0.8-35178-ubuntu-12.04-x86_64-free.tar.gz
#unzip


##CONFIGURE APACHE SERVER##########################
package "apache2"
package "libapache2-mod-php5"

service "apache2" do
  supports :reload => true
end



##CONFIGURE POSTFIX SERVER############################
package "postfix"
package "postfix-ldap"

service "postfix" do
  supports :restart => true
end

execute "postmap catchall" do
  action :nothing
  cwd "/etc/postfix"
  notifies :restart, resources(:service => "postfix")
end

ldap_server = search(:node, "recipes:openldap\\:\\:users && domain:#{node['domain']}").first

template "/etc/postfix/ldap-aliases.cf" do
  variables ({:ldap_server => ldap_server})
  notifies :restart, resources(:service => "postfix")
end

template "/etc/postfix/ldap-users.cf" do
  variables ({:ldap_server => ldap_server})
  notifies :restart, resources(:service => "postfix")
end

if not node['zarafa']['catchall'].nil?
  template "/etc/postfix/catchall" do
    notifies :run, resources(:execute => "postmap catchall")
  end
end

template "/etc/postfix/main.cf" do
  notifies :restart, resources(:service => "postfix")
end

## Setup Config for smtp auth
package "sasl2-bin"

service "saslauthd" do
  supports :restart => true
end

template "/etc/postfix/sasl/smtpd.conf" do
  notifies :restart, resources(:service => "postfix")
end

template "/etc/default/saslauthd" do
  notifies :restart, resources(:service => "postfix")
end

#set permissions for postfix
directory "/var/spool/postfix/var/run/saslauthd" do
  owner "postfix"
end

#TODO CONFIGURE MAILDIR

##CONFIGURE MYSQL SERVER#################################

node.set['mysql']['bind_address'] = "127.0.0.1"

include_recipe "mysql::server"
include_recipe "database::mysql"
mysql_connection_info = {:host => "localhost", :username => 'root', :password => node['mysql']['server_root_password']}

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
node.set_unless['zarafa']['mysql_password'] = secure_password

mysql_database_user node['zarafa']['mysql_user'] do
  username  node['zarafa']['mysql_user']
  password  node['zarafa']['mysql_password']
  database_name node['zarafa']['mysql_database']
  connection mysql_connection_info
  action :grant
end

mysql_database node['zarafa']['mysql_database'] do
  connection mysql_connection_info
  action :create
end 


##CONFIGURE ZARAFA#########################################

#install.sh
#TODO

#for zarafa webapp
directory "/var/lib/zarafa-webapp/tmp" do
  owner "www-data"
  group "www-data"
  mode 0755
end

#NOT needed: a2ensite zarafa-webapp => reload
#NOT needed: a2ensite zarafa-webaccess => reload



#not necessary - got by program itself package "php-gettext"
#internally: zarafa-admin -s

#zarafa-admin -c user

service "zarafa-server" do 
  supports :restart => true, :start => true
  action :start
end

service "zarafa-gateway" do 
  supports :restart => true, :start => true
  action :start
end

template "/etc/zarafa/ldap.cfg" do
  variables ({:ldap_server => ldap_server})
  notifies :restart, resources(:service=>"zarafa-server")
end

template "/etc/zarafa/server.cfg" do
  notifies :restart, resources(:service=>"zarafa-server")
end

template "/etc/zarafa/gateway.cfg" do
  notifies :restart, resources(:service=>"zarafa-gateway")
end

##CONFIGURE Z-PUSH############################################

#get and untar z-push
#template "/usr/share/z-push/config.php" => set timezone

directory "/var/lib/z-push" do
  mode 0755
  owner "www-data"
  group "www-data"
end
directory "/var/log/z-push" do
  mode 0755
  owner "www-data"
  group "www-data"
end

template "/etc/apache2/httpd.conf" do
  notifies :reload, resources(:service=>"apache2")
end

