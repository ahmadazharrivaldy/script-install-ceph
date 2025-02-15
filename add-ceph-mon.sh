#!/bin/bash

# Get FSID from the configuration file
FSID=$(grep "^fsid" /etc/ceph/ceph.conf | awk '{print $NF}')

# Define nodes and their IPs
declare -A NODES=(
    ["rz-ceph-mon02"]="<YOUR_IP>"
    ["rz-ceph-mon03"]="<YOUR_IP>"
)

# Loop through each node
for NODENAME in "${!NODES[@]}"; do
    NODEIP=${NODES[$NODENAME]}
    
    # Add the new node to the monmap
    echo "Adding $NODENAME with IP $NODEIP to monmap..."
    monmaptool --add $NODENAME $NODEIP --fsid $FSID /etc/ceph/monmap

    # Copy configuration files and keys to the new node
    echo "Copying configuration files to $NODENAME..."
    scp /etc/ceph/ceph.conf ${NODENAME}:/etc/ceph/ceph.conf
    scp /etc/ceph/ceph.mon.keyring ${NODENAME}:/etc/ceph
    scp /etc/ceph/monmap ${NODENAME}:/etc/ceph
    scp /etc/ceph/ceph.client.admin.keyring ${NODENAME}:/etc/ceph

    # Configure the Monitor Daemon on the new node
    echo "Configuring Monitor Daemon on $NODENAME..."
    ssh -o StrictHostKeyChecking=no $NODENAME << EOF
        ceph-mon --cluster ceph --mkfs -i $NODENAME --monmap /etc/ceph/monmap --keyring /etc/ceph/ceph.mon.keyring
        chown -R ceph. /etc/ceph /var/lib/ceph/mon
        ceph auth get mon. -o /etc/ceph/ceph.mon.keyring
        systemctl enable --now ceph-mon@$NODENAME
        ceph mon enable-msgr2
EOF
done

echo "Ceph Monitor addition process completed for all nodes!"
