#!/bin/bash

set -e

if [ "$1" = 'zammad-nfs' ]; then
  echo "create & mount tmpfs"

  test -d ${NFS_DIR_ROOT}/${NFS_DIR_DATA} || mkdir -p ${NFS_DIR_ROOT}/${NFS_DIR_DATA}
  test -d ${NFS_DIR_ROOT}/${NFS_DIR_TMP} || mkdir -p ${NFS_DIR_ROOT}/${NFS_DIR_TMP}

  chmod 777 ${NFS_DIR_ROOT}/${NFS_DIR_TMP} ${NFS_DIR_ROOT}/${NFS_DIR_DATA}

  mount -t tmpfs -o size=${TMPFS_SIZE} none ${NFS_DIR_ROOT}/${NFS_DIR_TMP}

  echo "create nfs exports"
  echo "# NFS Export for Zammad" > /etc/exports
  #echo "${NFS_DIR_DATA} *(rw,sync,no_subtree_check,fsid=0,no_root_squash)" >> /etc/exports
  #echo "${NFS_DIR_TMP} *(rw,sync,no_subtree_check,fsid=0,no_root_squash)" >> /etc/exports

  echo "${NFS_DIR_ROOT}/${NFS_DIR_DATA} *(rw,sync,no_subtree_check,fsid=0,no_root_squash)" >> /etc/exports
  echo "${NFS_DIR_ROOT}/${NFS_DIR_TMP} *(rw,sync,no_subtree_check,fsid=1,no_root_squash)" >> /etc/exports

  #exportfs -o rw,sync,no_subtree_check,fsid=0,no_root_squash ${NFS_DIR_DATA}
  #exportfs -o rw,sync,no_subtree_check,fsid=1,no_root_squash ${NFS_DIR_TMP}

  exec runsvdir /etc/sv
fi
