#!/bin/sh

set -e

function check_nfs_available {
  until (echo > /dev/tcp/zammad-nfs/2049) &> /dev/null; do
    echo "waiting for zammads nfsserver to be ready..."
    sleep 2
  done
  echo "nginx can access nfs server now..."
}

function mount_nfs {
  if [ -n "$(env|grep KUBERNETES)" ]; then
    check_nfs_available
    test -d ${ZAMMAD_DIR} || mkdir -p ${ZAMMAD_DIR}
    mount -t nfs4 zammad-nfs:/ ${ZAMMAD_DIR}
  fi
}

# zammad-railsserver
if [ "$1" = 'zammad-nginx' ]; then

  mount_nfs

  /usr/sbin/nginx -g 'daemon off;'

fi
