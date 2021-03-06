#!/bin/bash

######################
# Chapter 1 KEYSTONE #
######################

# Create database
sudo apt-get -y install ntp keystone python-keyring

# Config Files
export KEYSTONE_CONF=/etc/keystone/keystone.conf
export SSL_PATH=/etc/ssl/

export MYSQL_ROOT_PASS=openstack
export MYSQL_KEYSTONE_PASS=openstack
mysql -uroot -p$MYSQL_ROOT_PASS -e 'CREATE DATABASE keystone;'
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$MYSQL_KEYSTONE_PASS';"
mysql -uroot -p$MYSQL_ROOT_PASS -e "GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$MYSQL_KEYSTONE_PASS';"

sudo sed -i "s#^connection.*#connection = mysql://keystone:${MYSQL_KEYSTONE_PASS}@${MYSQL_HOST}/keystone#" ${KEYSTONE_CONF}
sudo sed -i 's/^#admin_token.*/admin_token = ADMIN/' ${KEYSTONE_CONF}
sudo sed -i 's,^#log_dir.*,log_dir = /var/log/keystone,' ${KEYSTONE_CONF}

sudo echo "use_syslog = True" >> ${KEYSTONE_CONF}
sudo echo "syslog_log_facility = LOG_LOCAL0" >> ${KEYSTONE_CONF}

sudo apt-get -y install python-keystoneclient

echo "
#[signing]
#certfile=/etc/keystone/ssl/certs/signing_cert.pem
#keyfile=/etc/keystone/ssl/private/signing_key.pem
#ca_certs=/etc/keystone/ssl/certs/ca.pem
#ca_key=/etc/keystone/ssl/private/cakey.pem
#key_size=2048
#valid_days=3650
#cert_subject=/C=US/ST=Unset/L=Unset/O=Unset/CN=172.16.0.200

[ssl]
enable = True
certfile = /etc/keystone/ssl/certs/signing_cert.pem
keyfile = /etc/keystone/ssl/private/signing_key.pem
ca_certs = /etc/keystone/ssl/certs/ca.pem
cert_subject=/C=US/ST=Unset/L=Unset/O=Unset/CN=192.168.100.200
#cert_subject=/C=US/ST=Unset/L=Unset/O=Unset/CN=172.16.0.200
ca_key = /etc/keystone/ssl/certs/cakey.pem" | sudo tee -a ${KEYSTONE_CONF}


rm -rf /etc/keystone/ssl
#mkdir /usr/local/etc/keystone
#rm -rf /usr/local/etc/keystone/ssl
sudo keystone-manage ssl_setup --keystone-user keystone --keystone-group keystone
sudo cp /etc/keystone/ssl/certs/ca.pem /etc/ssl/certs/ca.pem
sudo c_rehash /etc/ssl/certs/ca.pem
#chown keystone:keystone /usr/local/etc/keystone -R
#chmod o=u /usr/local/etc/keystone -R
#ln -sfn /usr/local/etc/keystone/ssl  /etc/keystone/ssl

#rm -rf /etc/keystone/ssl
#cp -r /vagrant/kaixi/files/ssl /etc/keystone/
#chmod o=u /etc/keystone/ssl -R

# This runs for both LDAP and non-LDAP configs
create_endpoints(){
  export ENDPOINT=${PUBLIC_IP}
  export INT_ENDPOINT=${INT_IP}
  export ADMIN_ENDPOINT=${ADMIN_IP}
  export SERVICE_TOKEN=ADMIN
  export SERVICE_ENDPOINT=https://${KEYSTONE_ADMIN_ENDPOINT}:35357/v2.0
  export PASSWORD=openstack
  export OS_CACERT=/etc/keystone/ssl/certs/ca.pem
  export OS_KEY=/etc/keystone/ssl/certs/cakey.pem

   # OpenStack Compute Nova API Endpoint
  keystone  service-create --name nova --type compute --description 'OpenStack Compute Service'

  # OpenStack Compute EC2 API Endpoint
  keystone  service-create --name ec2 --type ec2 --description 'EC2 Service'

  # Glance Image Service Endpoint
  keystone  service-create --name glance --type image --description 'OpenStack Image Service'

  # Keystone Identity Service Endpoint
  keystone  service-create --name keystone --type identity --description 'OpenStack Identity Service'

  # Cinder Block Storage Endpoint
  keystone  service-create --name volume --type volume --description 'Volume Service'

  # Neutron Network Service Endpoint
  keystone  service-create --name network --type network --description 'Neutron Network Service'

  # OpenStack Compute Nova API
  NOVA_SERVICE_ID=$(keystone  service-list | awk '/\ nova\ / {print $2}')

  PUBLIC="http://$ENDPOINT:8774/v2/\$(tenant_id)s"
  ADMIN="http://$ADMIN_ENDPOINT:8774/v2/\$(tenant_id)s"
  INTERNAL="http://$INT_ENDPOINT:8774/v2/\$(tenant_id)s"

  keystone  endpoint-create --region regionOne --service_id $NOVA_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

  # OpenStack Compute EC2 API
  EC2_SERVICE_ID=$(keystone  service-list | awk '/\ ec2\ / {print $2}')

  PUBLIC="http://$ENDPOINT:8773/services/Cloud"
  ADMIN="http://$ADMIN_ENDPOINT:8773/services/Admin"
  INTERNAL="http://$INT_ENDPOINT:8773/services/Cloud"

  keystone  endpoint-create --region regionOne --service_id $EC2_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

  # Glance Image Service
  GLANCE_SERVICE_ID=$(keystone  service-list | awk '/\ glance\ / {print $2}')

  PUBLIC="http://$ENDPOINT:9292/v2"
  ADMIN="http://$ADMIN_ENDPOINT:9292/v2"
  INTERNAL="http://$INT_ENDPOINT:9292/v2"

  keystone  endpoint-create --region regionOne --service_id $GLANCE_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

  # Keystone OpenStack Identity Service
  KEYSTONE_SERVICE_ID=$(keystone  service-list | awk '/\ keystone\ / {print $2}')

  PUBLIC="https://$ENDPOINT:5000/v2.0"
  ADMIN="https://$ADMIN_ENDPOINT:35357/v2.0"
  INTERNAL="https://$INT_ENDPOINT:5000/v2.0"

  keystone  endpoint-create --region regionOne --service_id $KEYSTONE_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

  # Cinder Block Storage Service
  CINDER_SERVICE_ID=$(keystone  service-list | awk '/\ volume\ / {print $2}')

  #Dynamically determine first three octets if user specifies alternative IP ranges.  Fourth octet still hardcoded
  CINDER_ENDPOINT=$(ifconfig eth1 | awk '/inet addr/ {split ($2,A,":"); print A[2]}' | sed 's/\.[0-9]*$/.211/')
  PUBLIC="http://$CINDER_ENDPOINT:8776/v1/%(tenant_id)s"
  ADMIN=$PUBLIC
  INTERNAL=$PUBLIC

  keystone  endpoint-create --region regionOne --service_id $CINDER_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL

  # Neutron Network Service
  NEUTRON_SERVICE_ID=$(keystone  service-list | awk '/\ network\ / {print $2}')

  PUBLIC="http://$ENDPOINT:9696"
  ADMIN="http://$ADMIN_ENDPOINT:9696"
  INTERNAL="http://$INT_ENDPOINT:9696"

  keystone  endpoint-create --region regionOne --service_id $NEUTRON_SERVICE_ID --publicurl $PUBLIC --adminurl $ADMIN --internalurl $INTERNAL
}

# If LDAP is up, all the users/groups should be mapped already, leaving us to configure keystone and add in endpoints
configure_keystone(){
  echo "
[identity]
driver=keystone.identity.backends.ldap.Identity

[ldap]
url = ldap://openldap
user = cn=admin,ou=Users,dc=cook,dc=book
password = openstack
suffix = cn=cook,cn=book

user_tree_dn = ou=Users,dc=cook,dc=book
user_objectclass = inetOrgPerson
user_id_attribute = cn
user_mail_attribute = mail

user_enabled_attribute = userAccountControl
user_enabled_mask      = 2
user_enabled_default   = 512

tenant_tree_dn = ou=Groups,dc=cook,dc=book
tenant_objectclass = groupOfNames
tenant_id_attribute = cn
tenant_desc_attribute = description

use_dumb_member = True

role_tree_dn = ou=Roles,dc=cook,dc=book
role_objectclass = organizationalRole
role_id_attribute = cn
role_member_attribute = roleOccupant" | sudo tee -a ${KEYSTONE_CONF}

}

# Check if OpenLDAP is up and running, if so, configure keystone.
if ping -c 1 openldap
then
  echo "[+] Found OpenLDAP, Configuring Keystone."
  sudo stop keystone
  sudo start keystone
  sudo keystone-manage db_sync
  create_endpoints

  configure_keystone

  sudo stop keystone
  sudo start keystone
else
  echo "[+] OpenLDAP not found, moving along."
  sudo stop keystone
  sudo start keystone
  sudo keystone-manage db_sync

  export ENDPOINT=${PUBLIC_IP}
  export INT_ENDPOINT=${INT_IP}
  export ADMIN_ENDPOINT=${ADMIN_IP}
  export SERVICE_TOKEN=ADMIN
  export SERVICE_ENDPOINT=https://${KEYSTONE_ADMIN_ENDPOINT}:35357/v2.0
  export PASSWORD=openstack

  # admin role
  keystone  role-create --name admin

  # Member role
  keystone  role-create --name Member

  keystone  role-list

  keystone  tenant-create --name cookbook --description "Default Cookbook Tenant" --enabled true

  TENANT_ID=$(keystone  tenant-list | awk '/\ cookbook\ / {print $2}')

  keystone  user-create --name admin --tenant_id $TENANT_ID --pass $PASSWORD --email root@localhost --enabled true

  TENANT_ID=$(keystone  tenant-list | awk '/\ cookbook\ / {print $2}')

  ROLE_ID=$(keystone  role-list | awk '/\ admin\ / {print $2}')

  USER_ID=$(keystone  user-list | awk '/\ admin\ / {print $2}')

  keystone  user-role-add --user $USER_ID --role $ROLE_ID --tenant_id $TENANT_ID

  # Create the user
  PASSWORD=openstack
  keystone  user-create --name demo --tenant_id $TENANT_ID --pass $PASSWORD --email demo@localhost --enabled true

  TENANT_ID=$(keystone  tenant-list | awk '/\ cookbook\ / {print $2}')

  ROLE_ID=$(keystone  role-list | awk '/\ Member\ / {print $2}')

  USER_ID=$(keystone  user-list | awk '/\ demo\ / {print $2}')

  # Assign the Member role to the demo user in cookbook
  keystone  user-role-add --user $USER_ID --role $ROLE_ID --tenant_id $TENANT_ID

  create_endpoints

  # Service Tenant
  keystone  tenant-create --name service --description "Service Tenant" --enabled true

  SERVICE_TENANT_ID=$(keystone  tenant-list | awk '/\ service\ / {print $2}')

  keystone  user-create --name nova --pass nova --tenant_id $SERVICE_TENANT_ID --email nova@localhost --enabled true

  keystone  user-create --name glance --pass glance --tenant_id $SERVICE_TENANT_ID --email glance@localhost --enabled true

  keystone  user-create --name keystone --pass keystone --tenant_id $SERVICE_TENANT_ID --email keystone@localhost --enabled true

  keystone  user-create --name cinder --pass cinder --tenant_id $SERVICE_TENANT_ID --email cinder@localhost --enabled true

  keystone  user-create --name neutron --pass neutron --tenant_id $SERVICE_TENANT_ID --email neutron@localhost --enabled true

  # Get the nova user id
  NOVA_USER_ID=$(keystone  user-list | awk '/\ nova\ / {print $2}')

  # Get the admin role id
  ADMIN_ROLE_ID=$(keystone  role-list | awk '/\ admin\ / {print $2}')

  # Assign the nova user the admin role in service tenant
  keystone  user-role-add --user $NOVA_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

  # Get the glance user id
  GLANCE_USER_ID=$(keystone  user-list | awk '/\ glance\ / {print $2}')

  # Assign the glance user the admin role in service tenant
  keystone  user-role-add --user $GLANCE_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

  # Get the keystone user id
  KEYSTONE_USER_ID=$(keystone  user-list | awk '/\ keystone\ / {print $2}')

  # Assign the keystone user the admin role in service tenant
  keystone  user-role-add --user $KEYSTONE_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

  # Get the cinder user id
  CINDER_USER_ID=$(keystone  user-list | awk '/\ cinder \ / {print $2}')

  # Assign the cinder user the admin role in service tenant
  keystone  user-role-add --user $CINDER_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID

  # Create neutron service user in the services tenant
  NEUTRON_USER_ID=$(keystone  user-list | awk '/\ neutron \ / {print $2}')

  # Grant admin role to neutron service user
  keystone  user-role-add --user $NEUTRON_USER_ID --role $ADMIN_ROLE_ID --tenant_id $SERVICE_TENANT_ID
fi


