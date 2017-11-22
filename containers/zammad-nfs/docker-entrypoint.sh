#!/bin/bash

set -e

if [ "$1" = 'zammad-nfs' ]; then
  echo "create & mount tmpfs"
  mount -t tmpfs -o size=${TMPFS_SIZE} none ${NFS_DIR}/tmp

  echo "create nfs exports"
  echo "# NFS Export for Zammad" > /etc/exports
  echo "${NFS_DIR} *(rw,sync,no_subtree_check,fsid=0,no_root_squash)" >> /etc/exports

  exec runsvdir /etc/sv
fi
