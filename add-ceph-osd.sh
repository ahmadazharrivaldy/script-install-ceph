#!/bin/bash

# List of nodes to be processed
NODES=("rz-ceph-node01" "rz-ceph-node02" "rz-ceph-node03")

# Variable for the storage device
STORAGE_DEVICE="/dev/vdb"

# Loop through each node
for NODE in "${NODES[@]}"
do
    echo "Copying files to $NODE..."
    # Copy configuration files and keys to the other node
    scp /etc/ceph/ceph.conf ${NODE}:/etc/ceph/ceph.conf
    scp /etc/ceph/ceph.client.admin.keyring ${NODE}:/etc/ceph
    scp /var/lib/ceph/bootstrap-osd/ceph.keyring ${NODE}:/var/lib/ceph/bootstrap-osd

    echo "Configuring $NODE..."
    # Access the node and run commands
    ssh -o StrictHostKeyChecking=no $NODE << EOF
        # Change ownership of files
        chown ceph. /etc/ceph/ceph.* /var/lib/ceph/bootstrap-osd/*

        # Create label and partition on the storage device
        parted --script $STORAGE_DEVICE mklabel gpt
        parted --script $STORAGE_DEVICE mkpart primary 0% 100%

        # Create LVM with ceph-volume
        ceph-volume lvm create --data ${STORAGE_DEVICE}1
EOF
done

echo "Process completed for all nodes!"
