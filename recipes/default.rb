#
# Cookbook Name:: jenkins
# Based on hudson
# Recipe:: default
#
# Author:: Scott Likens <scott@likens.us>
# Author:: AJ Christensen <aj@junglist.gen.nz>
# Author:: Doug MacEachern <dougm@vmware.com>
# Author:: Fletcher Nichol <fnichol@nichol.ca>
#
# Copyright 2010, VMware, Inc.
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
pid_file = "/var/run/jenkins/jenkins.pid"
pkey = "#{node[:jenkins][:server][:home]}/.ssh/id_rsa"
tmp = "/tmp"

user node[:jenkins][:server][:user] do
  home node[:jenkins][:server][:home]
end

directory node[:jenkins][:server][:home] do
  recursive true
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
end

directory "#{node[:jenkins][:server][:home]}/.ssh" do
  mode 0700
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
end

execute "ssh-keygen -f #{pkey} -N ''" do
  user  node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
  not_if { File.exists?(pkey) }
end

ruby_block "store jenkins ssh pubkey" do
  block do
    node.set[:jenkins][:server][:pubkey] = File.open("#{pkey}.pub") { |f| f.gets }
  end
end

directory "#{node[:jenkins][:server][:home]}/plugins" do
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
  only_if { node[:jenkins][:server][:plugins].size > 0 }
end

node[:jenkins][:server][:plugins].each do |name|
  remote_file "#{node[:jenkins][:server][:home]}/plugins/#{name}.hpi" do
    source "#{node[:jenkins][:mirror]}/plugins/#{name}/latest/#{name}.hpi"
    backup false
    owner node[:jenkins][:server][:user]
    group node[:jenkins][:server][:group]
  end
end

directory "/usr/share/jenkins" do
  action :create
  owner "nobody"
  group "nogroup"
  recursive true
end

remote_file "/usr/share/jenkins/jenkins.war" do
  source "#{node[:jenkins][:mirror_url]}/#{node[:jenkins][:version]}/jenkins.war"
  owner "root"
  group "root"
  mode 0644
end

package "daemon"
include_recipe "java"
#"jenkins stop" may (likely) exit before the process is actually dead
#so we sleep until nothing is listening on jenkins.server.port (according to netstat)
ruby_block "netstat" do
  block do
    10.times do
      if IO.popen("netstat -lnt").entries.select { |entry|
          entry.split[3] =~ /:#{node[:jenkins][:server][:port]}$/
        }.size == 0
        break
      end
      Chef::Log.debug("service[jenkins] still listening (port #{node[:jenkins][:server][:port]})")
      sleep 1
    end
  end
  action :nothing
end

ruby_block "block_until_operational" do
  block do
    until IO.popen("netstat -lnt").entries.select { |entry|
        entry.split[3] =~ /:#{node[:jenkins][:server][:port]}$/
      }.size == 1
      Chef::Log.debug "service[jenkins] not listening on port #{node.jenkins.server.port}"
      sleep 1
    end

    loop do
      url = URI.parse("#{node.jenkins.server.url}/job/test/config.xml")
      res = Chef::REST::RESTRequest.new(:GET, url, nil).call
      break if res.kind_of?(Net::HTTPSuccess) or res.kind_of?(Net::HTTPNotFound)
      Chef::Log.debug "service[jenkins] not responding OK to GET / #{res.inspect}"
      sleep 1
    end
  end
  action :nothing
end

template "/etc/default/jenkins"

template "/etc/init.d/jenkins" do
  source "jenkins"
  mode 0755
end

service "jenkins" do
  supports [ :stop, :start, :restart, :status ]
  status_command "test -f #{pid_file} && kill -0 `cat #{pid_file}`"
  action :nothing
end

# restart if this run only added new plugins
log "plugins updated, restarting jenkins" do
  #ugh :restart does not work, need to sleep after stop.
  notifies :stop, "service[jenkins]", :immediately
  notifies :create, "ruby_block[netstat]", :immediately
  notifies :start, "service[jenkins]", :immediately
  notifies :create, "ruby_block[block_until_operational]", :immediately
  only_if do
    if File.exists?(pid_file)
      htime = File.mtime(pid_file)
      Dir["#{node[:jenkins][:server][:home]}/plugins/*.hpi"].select { |file|
        File.mtime(file) > htime
      }.size > 0
    end
  end

  action :nothing
end

# Front Jenkins with an HTTP server
case node[:jenkins][:http_proxy][:variant]
when "nginx"
  include_recipe "jenkins::proxy_nginx"
when "apache2"
  include_recipe "jenkins::proxy_apache2"
end

if node.jenkins.iptables_allow == "enable"
  include_recipe "iptables"
  iptables_rule "port_jenkins" do
    if node[:jenkins][:iptables_allow] == "enable"
      enable true
    else
      enable false
    end
  end
end
service "jenkins" do
  supports [ :stop, :start, :restart, :status ]
  status_command "test -f #{pid_file} && kill -0 `cat #{pid_file}`"
  action [:start,:enable]
end
execute "start jenkins" do
  command "/etc/init.d/jenkins start"
  not_if 'ps auxwww | grep [j]enkins'
end
