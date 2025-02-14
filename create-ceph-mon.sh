#!/bin/bash

# Generate a new UUID for the FSID
FSID=$(uuidgen)
echo "Generated FSID: $FSID"

# Set the cluster name and node name
CLUSTER_NAME="ceph"
NODE_NAME="ceph-mon01"
NODE_IP="<YOUR_IP>"
CLUSTER_NETWORK="<YOUR_NETWORK_IP/24>"
PUBLIC_NETWORK="<YOUR_NETWORK_IP/24>"

# Create the Ceph configuration file
cat <<EOL > /etc/ceph/$CLUSTER_NAME.conf
[global]
cluster network = $CLUSTER_NETWORK
public network = $PUBLIC_NETWORK
fsid = $FSID
mon host = $NODE_IP
mon initial members = $NODE_NAME
osd pool default crush rule = -1

[mon.$NODE_NAME]
host = $NODE_NAME
mon addr = $NODE_IP
mon allow pool delete = true
EOL

# Generate secret keys
ceph-authtool --create-keyring /etc/ceph/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring --gen-key -n client.bootstrap-osd --cap mon 'profile bootstrap-osd' --cap mgr 'allow r'

# Import generated keys
ceph-authtool /etc/ceph/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
ceph-authtool /etc/ceph/ceph.mon.keyring --import-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring

# Generate monitor map
monmaptool --create --add $NODE_NAME $NODE_IP --fsid $FSID /etc/ceph/monmap

# Create directory for Monitor Daemon
mkdir -p /var/lib/ceph/mon/ceph-$NODE_NAME

# Associate key and monmap to Monitor Daemon
ceph-mon --cluster $CLUSTER_NAME --mkfs -i $NODE_NAME --monmap /etc/ceph/monmap --keyring /etc/ceph/ceph.mon.keyring

# Set ownership
chown ceph. /etc/ceph/ceph.*
chown -R ceph. /var/lib/ceph/mon/ceph-$NODE_NAME /var/lib/ceph/bootstrap-osd

# Enable and start the Monitor service
systemctl enable --now ceph-mon@$NODE_NAME

# Enable Messenger v2 Protocol
ceph mon enable-msgr2
ceph config set mon auth_allow_insecure_global_id_reclaim false

# Enable Placement Groups auto scale module
ceph mgr module enable pg_autoscaler

# Create directory for Manager Daemon
mkdir -p /var/lib/ceph/mgr/ceph-$NODE_NAME

# Create auth key for Manager
ceph auth get-or-create mgr.$NODE_NAME mon 'allow profile mgr' osd 'allow *' mds 'allow *'

# Save the Manager keyring
ceph auth get-or-create mgr.$NODE_NAME | tee /etc/ceph/ceph.mgr.admin.keyring
cp /etc/ceph/ceph.mgr.admin.keyring /var/lib/ceph/mgr/ceph-$NODE_NAME/keyring

# Set ownership for Manager keyring
chown ceph. /etc/ceph/ceph.mgr.admin.keyring
chown -R ceph. /var/lib/ceph/mgr/ceph-$NODE_NAME

# Enable and start the Manager service
systemctl enable --now ceph-mgr@$NODE_NAME

echo "Ceph installation and configuration completed successfully!"
