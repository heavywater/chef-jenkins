#
# Cookbook Name:: jenkins
# Provider:: plugin
#
# A LWRP for installing Jenkins plugins.
#
# Copyright 2012, DrillingInfo, Inc
#

require 'chef/mixin/checksum'

include Chef::Mixin::Checksum

PLUGINS_BASE = "http://updates.jenkins-ci.org/download/plugins"
LATEST_PLUGIN_BASE = "http://updates.jenkins-ci.org/latest"
PLUGINS_HOME = "/var/lib/jenkins/plugins"

action :install do
    
    log "Installing jenkins plugin '#{new_resource.name}' from #{download_url_for new_resource}"

    remote_file destination_for new_resource do
        source download_url_for new_resource
        owner "jenkins"
        group "adm"
        mode  "750"
        backup false
        notifies :record, resources(:jenkins_plugin => new_resource.name), :delayed
        notifies :restart, resources(:service => "jenkins"), :delayed
    end
    
end

action :record do
    record_plugin_information_for new_resource
end

def destination_for new_resource
    return "#{PLUGINS_HOME}/#{plugin_filename_for new_resource}"
end

def download_url_for new_resource
    if new_resource.download_url.nil? then
        calculated_url_for new_resource
    else
        new_resource.download_url
    end
end

def calculated_url_for new_resource
    if new_resource.version.nil? then
        "#{LATEST_PLUGIN_BASE}/#{plugin_filename_for new_resource}"
    else
        "#{PLUGINS_BASE}/#{new_resource.name}/#{new_resource.version}/#{plugin_filename_for new_resource}"
    end
end

def plugin_filename_for new_resource
    return "#{new_resource.name}.hpi"
end

def record_plugin_information_for new_resource
    node.set[:jenkins][:plugins][new_resource.name][:version] = plugin_version
    node.set[:jenkins][:plugins][new_resource.name][:url] = download_url_for new_resource
    node.set[:jenkins][:plugins][new_resource.name][:sha] = sha_for new_resource
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
    checksum(destination_for new_resource)
end
