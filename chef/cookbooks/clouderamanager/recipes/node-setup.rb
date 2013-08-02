#
# Cookbook Name: clouderamanager
# Recipe: node-setup.rb
#
# Copyright (c) 2011 Dell Inc.
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

#######################################################################
# Begin recipe
#######################################################################
debug = node[:clouderamanager][:debug]
Chef::Log.info("CM - BEGIN clouderamanager:node-setup") if debug

# Configuration filter for the crowbar environment
env_filter = " AND environment:#{node[:clouderamanager][:config][:environment]}"

#######################################################################
# Install the xfs file system support packages.
#######################################################################
fs_type = node[:clouderamanager][:os][:fs_type]
if fs_type == 'xfs'
  xfs_packages=%w{
    xfsprogs
  }
  
  xfs_packages.each do |pkg|
    package pkg do
      action :install
    end
  end
end

#######################################################################
# Ensure localtime is set consistently across the cluster (UTC).
#######################################################################
file "/etc/localtime" do
  action :delete
  only_if "test -F /etc/localtime"
end

link "/etc/localtime" do
  to "/usr/share/zoneinfo/Etc/UTC"
end




#######################################################################
# Ensure THP compaction is disabled/enabled based on user input.
#######################################################################

Chef::Log.info("OS - Change thp settings") if debug
disable = node[:clouderamanager][:os][:thp_compaction]
defrag_file_pathname = "/sys/kernel/mm/redhat_transparent_hugepage/defrag"
rc_local_path = "/etc/rc.local"

# For future reboots, change rc.local file on the node.

if File.exists?(rc_local_path)
  text = File.read(rc_local_path)
  if (text =~ /\s*[a-z]+ > \/sys\/kernel\/mm\/redhat_transparent_hugepage\/defrag\s*/)
    
     replace = text.gsub(/\s*[a-z ]+ > \/sys\/kernel\/mm\/redhat_transparent_hugepage\/defrag\s*/, "echo #{disable} > #{defrag_file_pathname}\n")

     File.open(rc_local_path, "w") { |file| file.puts replace }
     Chef::Log.info("OS - Successfully changed thp_compaction value for rc.local file.")
  else
    Chef::Log.info("OS - Append to end of file")
    %x{sudo sh -c "echo '#{disable} > #{defrag_file_pathname}' >> #{rc_local_path}"}
  end
else
  Chef::Log.info("OS - Changing thp_compaction value for rc.local file failed.")
end


Chef::Log.info("Executing thp change for current session")
#Change it for current session
output = %x{echo #{disable} > #{defrag_file_pathname}}
if $?.exitstatus != 0
 Chef::Log.error("OS - Failed to change thp_compaction value for current session") if debug
else
 Chef::Log.info("OS - Successfully changed thp_compaction value for current session") if debug
end

#----------------------------------------------------------------------
# Find the name nodes. 
#----------------------------------------------------------------------
namenodes = []
search(:node, "roles:clouderamanager-namenode#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key }
    Chef::Log.info("CM - NAMENODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    namenodes << node_rec
  end
end
node[:clouderamanager][:cluster][:namenodes] = namenodes

#----------------------------------------------------------------------
# Find the data nodes. 
#----------------------------------------------------------------------
datanodes = []
search(:node, "roles:clouderamanager-datanode#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    hdfs_mounts = n[:clouderamanager][:hdfs][:hdfs_mounts] 
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key, :hdfs_mounts => hdfs_mounts}
    Chef::Log.info("CM - DATANODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    datanodes << node_rec 
  end
end
node[:clouderamanager][:cluster][:datanodes] = datanodes

#----------------------------------------------------------------------
# Find the edge nodes. 
#----------------------------------------------------------------------
edgenodes = []
search(:node, "roles:clouderamanager-edgenode#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key }
    Chef::Log.info("CM - EDGENODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    edgenodes << node_rec 
  end
end
node[:clouderamanager][:cluster][:edgenodes] = edgenodes

#----------------------------------------------------------------------
# Find the CM server nodes. 
#----------------------------------------------------------------------
cmservernodes = []
search(:node, "roles:clouderamanager-server#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key }
    Chef::Log.info("CM - CMSERVERNODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    cmservernodes << node_rec 
  end
end
node[:clouderamanager][:cluster][:cmservernodes] = cmservernodes

#----------------------------------------------------------------------
# Find the HA filer nodes. 
#----------------------------------------------------------------------
hafilernodes = []
search(:node, "roles:clouderamanager-ha-filernode#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key }
    Chef::Log.info("CM - FILERNODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    hafilernodes << node_rec 
  end
end
node[:clouderamanager][:cluster][:hafilernodes] = hafilernodes

#----------------------------------------------------------------------
# Find the HA journaling nodes. 
#----------------------------------------------------------------------
hajournalingnodes = []
search(:node, "roles:clouderamanager-ha-journalingnode#{env_filter}") do |n|
  if n[:fqdn] and not n[:fqdn].empty?
    ipaddr = BarclampLibrary::Barclamp::Inventory.get_network_by_type(n,"admin").address
    ssh_key = n[:crowbar][:ssh][:root_pub_key] rescue nil
    node_rec = { :fqdn => n[:fqdn], :ipaddr => ipaddr, :name => n.name, :ssh_key => ssh_key }
    Chef::Log.info("CM - JOURNALINGNODE [#{node_rec[:fqdn]}, #{node_rec[:ipaddr]}]") if debug
    hajournalingnodes << node_rec 
  end
end
node[:clouderamanager][:cluster][:hajournalingnodes] = hajournalingnodes

node.save 

#######################################################################
# End recipe
#######################################################################
Chef::Log.info("CM - END clouderamanager:node-setup") if debug
