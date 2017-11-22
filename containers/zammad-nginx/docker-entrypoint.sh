#!/bin/sh

set -e

# zammad-railsserver
if [ "$1" = 'zammad-nginx' ]; then

  if [ -n "$(env|grep KUBERNETES)" ]; then
    test -d ${ZAMMAD_DIR} || mkdir -p ${ZAMMAD_DIR}
    mount -t nfs4 zammad-nfs:/ ${ZAMMAD_DIR}
  fi

  /usr/sbin/nginx -g 'daemon off;'

fi
