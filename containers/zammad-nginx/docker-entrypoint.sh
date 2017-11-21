#!/bin/bash

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
    mount -t nfs4 zammad-nfs:/ /home/zammad
  fi
}


# zammad-railsserver
if [ "$1" = 'zammad-nginx' ]; then


  echo "scheduler can access raillsserver now..."

  mount_nfs

  # start scheduler
  cd ${ZAMMAD_DIR}
  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/scheduler.rb run
fi
