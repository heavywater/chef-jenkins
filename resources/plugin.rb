#
# Cookbook Name:: jenkins
# Resource:: plugin
#
# Author:: Greg Symons <gsymons@drillinginfo.com>
#
# A resource definition for Jenkins plugins.
#
# Copyright 2012, DrillingInfo, Inc
#

def initialize(*args)
    super
    @action = :install
end

actions :install
attribute :name, :kind_of => String, :name_attribute => true
attribute :version, :kind_of => String
attribute :download_url, :kind_of => String
