#
# Cookbook Name:: jenkins
# Based on hudson
# Recipe:: war
#
# Author:: Pierre Ozoux <pierre.ozoux@gmail.com>
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

include_recipe "java"


node.set[:jenkins][:server][:pid_file] = "/var/run/jenkins.pid"

directory node[:jenkins][:server][:java_war_dir] do
  mode 0755
end

directory node[:jenkins][:server][:log_dir] do
  mode 0755
  owner node[:jenkins][:server][:user]
  group node[:jenkins][:server][:group]
end

remote_file "#{node.jenkins.server.java_war_dir}/jenkins.war" do
  source node[:jenkins][:war_url]
  mode 00644
end

#init method
#It works on Gentoo, didn't test on other platform, that's why there is the test.
if node.platform == "gentoo"

  template "/etc/init.d/jenkins" do
    source "init.d.erb"
    mode 0755
    owner "root"
    group "root"
  end

  template "/etc/conf.d/jenkins" do
    source "conf.d.erb"
    mode 0644
    owner "root"
    group "root"
  end
else
  #your init method
end
