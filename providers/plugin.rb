#
# Cookbook Name:: jenkins
# Provider:: plugin
#
# A LWRP for installing Jenkins plugins.
#
# Author:: Greg Symons <gsymons@drillinginfo.com>
#
# Copyright 2012, DrillingInfo, Inc
#

require 'chef/mixin/checksum'

include Chef::Mixin::Checksum

action :install do
    
    log "Installing jenkins plugin '#{new_resource.name}' from #{download_url_for new_resource}"

    remote_file destination_for new_resource do
        source download_url_for new_resource
        owner node[:jenkins][:user]
        group node[:jenkins][:group]
        mode  "644"
        backup false
        checksum sha_for(new_resource)
        notifies :record, resources('chef-jenkins_plugin' => new_resource.name), :delayed
        notifies :restart, resources(:service => "jenkins"), :delayed
    end
end

action :record do
    chef_gem 'rubyzip'

    record_plugin_information_for new_resource
end

def destination_for new_resource
    return "#{plugins_home}/#{plugin_filename_for new_resource}"
end

def plugins_home
    "#{node[:jenkins][:server][:home]}/plugins"
end

def download_url_for new_resource
    if new_resource.download_url.nil? then
        calculated_url_for new_resource
    else
        new_resource.download_url
    end
end

def calculated_url_for new_resource
    plugins_base_url = "#{node[:jenkins][:mirror]}/plugins"
    version = new_resource.version || 'latest'
    plugin_file = plugin_filename_for new_resource
    plugin = new_resource.name

    "#{plugins_base_url}/#{plugin}/#{version}/#{plugin_file}"
end

def plugin_filename_for new_resource
    return "#{new_resource.name}.hpi"
end

def record_plugin_information_for new_resource
    node.set[:jenkins][:server][:plugins][new_resource.name][:version] = plugin_version
    node.set[:jenkins][:server][:plugins][new_resource.name][:url] = download_url_for new_resource
    node.set[:jenkins][:server][:plugins][new_resource.name][:sha] = sha_for new_resource
end

def plugin_version
     if new_resource.version.nil? then
         plugin_version_from_file new_resource
     else
         new_resource.version
     end
end

def plugin_version_from_file new_resource
    require 'zip/zip'

    Zip::ZipFile.open(destination_for new_resource) do |zipfile|
        zipfile.get_input_stream("META-INF/MANIFEST.MF") do |manifest|
            manifest.each_line do |line|
                if line.start_with?("Plugin-Version") then
                    return line.split(":").last.strip
                end
            end
        end
    end
    return "Unknown"
end

def sha_for new_resource
    if ::File.exists? destination_for new_resource
        checksum(destination_for new_resource)
    end
end
