#
# Cookbook Name:: jenkins
# Based on hudson
# Recipe:: package
#
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

case node.platform
when "ubuntu", "debian"
  include_recipe "apt"
  include_recipe "java"

  node.set[:jenkins][:server][:pid_file] = "/var/run/jenkins/jenkins.pid"

  apt_repository "jenkins" do
    uri "#{node.jenkins.package_url}/debian"
    components %w[binary/]
    key "http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key"
    action :add
  end
when "centos", "redhat"
  include_recipe "yum"

  node.set[:jenkins][:server][:pid_file] = "/var/run/jenkins.pid"

  yum_key "jenkins" do
    url "#{node.jenkins.package_url}/redhat/jenkins-ci.org.key"
    action :add
  end

  yum_repository "jenkins" do
    description "repository for jenkins"
    url "#{node.jenkins.package_url}/redhat/"
    key "jenkins"
    action :add
  end
end

notifies :install, "package[jenkins]", :immediately

template "/etc/default/jenkins"

package "jenkins" do
  action :nothing
  notifies :create, "template[/etc/default/jenkins]", :immediately
end
