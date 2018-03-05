#!/bin/bash

#Author HOC CHU DONG

source function.sh
source config.cfg

# Function install nova-compute
function nova_install () {
	echocolor "Install nova-compute"
	sleep 3
	apt install nova-compute -y
}

# Function edit /etc/nova/nova.conf file
function nova_config () {
	echocolor "Edit /etc/nova/nova.conf file"
	sleep 3
	novafile=/etc/nova/nova.conf
	novafilebak=/etc/nova/nova.conf.bak
	cp $novafile $novafilebak
	egrep -v "^$|^#" $novafilebak > $novafile

	ops_add $novafile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL1_IP_NIC2

	ops_add $novafile api auth_strategy keystone

	ops_add $novafile keystone_authtoken auth_uri http://$CTL1_IP_NIC2:5000
	ops_add $novafile keystone_authtoken auth_url http://$CTL1_IP_NIC2:5000
	ops_add $novafile keystone_authtoken memcached_servers $CTL1_IP_NIC2:11211
	ops_add $novafile keystone_authtoken auth_type password
	ops_add $novafile keystone_authtoken project_domain_name default
	ops_add $novafile keystone_authtoken user_domain_name default
	ops_add $novafile keystone_authtoken project_name service
	ops_add $novafile keystone_authtoken username nova
	ops_add $novafile keystone_authtoken password $NOVA_PASS

	ops_add $novafile DEFAULT my_ip $CTL1_IP_NIC2
	ops_add $novafile DEFAULT use_neutron True
	ops_add $novafile DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

	ops_add $novafile vnc enabled True
	ops_add $novafile vnc vncserver_listen 0.0.0.0
	ops_add $novafile vnc vncserver_proxyclient_address \$my_ip
	ops_add $novafile vnc novncproxy_base_url http://$CTL1_IP_NIC2:6080/vnc_auto.html

	ops_add $novafile glance api_servers http://$CTL1_IP_NIC2:9292
	ops_add $novafile oslo_concurrency lock_path /var/lib/nova/tmp
	ops_del $novafile DEFAULT log_dir

	ops_del $novafile placement os_region_name
	ops_add $novafile placement os_region_name RegionOne
	ops_add $novafile placement project_domain_name Default
	ops_add $novafile placement project_name service
	ops_add $novafile placement auth_type password
	ops_add $novafile placement user_domain_name Default
	ops_add $novafile placement auth_url http://$CTL1_IP_NIC2:5000/v3
	ops_add $novafile placement username placement
	ops_add $novafile placement password $PLACEMENT_PASS
}

# Function finalize installation
function nova_resart () {
	echocolor "Finalize installation"
	sleep 3
	service nova-compute restart
}


function neutron_install () {
	echocolor "Install the components Neutron"
	sleep 3

	apt install neutron-linuxbridge-agent -y
}

# Function configure the common component
function neutron_config_server_component () {
	echocolor "Configure the common component"
	sleep 3

	neutronfile=/etc/neutron/neutron.conf
	neutronfilebak=/etc/neutron/neutron.conf.bak
	cp $neutronfile $neutronfilebak
	egrep -v "^$|^#" $neutronfilebak > $neutronfile

	ops_del $neutronfile database connection
	ops_add $neutronfile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL1_IP_NIC2

	ops_add $neutronfile DEFAULT auth_strategy keystone
	ops_add $neutronfile keystone_authtoken auth_uri http://$CTL1_IP_NIC2:5000
	ops_add $neutronfile keystone_authtoken auth_url http://$CTL1_IP_NIC2:5000
	ops_add $neutronfile keystone_authtoken memcached_servers $CTL1_IP_NIC2:11211
	ops_add $neutronfile keystone_authtoken auth_type password
	ops_add $neutronfile keystone_authtoken project_domain_name default
	ops_add $neutronfile keystone_authtoken user_domain_name default
	ops_add $neutronfile keystone_authtoken project_name service
	ops_add $neutronfile keystone_authtoken username neutron
	ops_add $neutronfile keystone_authtoken password $NEUTRON_PASS
}

# Function configure the Linux bridge agent
function neutron_config_linuxbridge () {
	echocolor "Configure the Linux bridge agent"
	sleep 3
	linuxbridgefile=/etc/neutron/plugins/ml2/linuxbridge_agent.ini
	linuxbridgefilebak=/etc/neutron/plugins/ml2/linuxbridge_agent.ini.bak
	cp $linuxbridgefile $linuxbridgefilebak
	egrep -v "^$|^#" $linuxbridgefilebak > $linuxbridgefile

	ops_add $linuxbridgefile linux_bridge physical_interface_mappings provider:ens5
	ops_add $linuxbridgefile vxlan enable_vxlan false
	ops_add $linuxbridgefile securitygroup enable_security_group true
	ops_add $linuxbridgefile securitygroup \
		firewall_driver neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
}

# Function configure the Compute service to use the Networking service
function neutron_config_compute_use_network () {
	echocolor "Configure the Compute service to use the Networking service"
	sleep 3
	novafile=/etc/nova/nova.conf

	ops_add $novafile neutron url http://$CTL1_IP_NIC2:9696
	ops_add $novafile neutron auth_url http://$CTL1_IP_NIC2:5000
	ops_add $novafile neutron auth_type password
	ops_add $novafile neutron project_domain_name default
	ops_add $novafile neutron user_domain_name default
	ops_add $novafile neutron region_name RegionOne
	ops_add $novafile neutron project_name service
	ops_add $novafile neutron username neutron
	ops_add $novafile neutron password $NEUTRON_PASS
	ops_add $novafile neutron service_metadata_proxy true
	ops_add $novafile neutron metadata_proxy_shared_secret $METADATA_SECRET	
}

# Function restart installation
function neutron_restart () {
	echocolor "Finalize installation"
	sleep 3
	service nova-compute restart
	service neutron-linuxbridge-agent restart
}


#######################
###Execute functions###
#######################

# Install nova-compute
nova_install

# Edit /etc/nova/nova.conf file
nova_config

# Finalize installation
nova_resart


#######################
###Execute functions###
#######################

# Install the components Neutron
neutron_install

# Configure the common component
neutron_config_server_component

# Configure the Linux bridge agent
neutron_config_linuxbridge
	
# Configure the Compute service to use the Networking service
neutron_config_compute_use_network
	
# Restart installation
neutron_restart