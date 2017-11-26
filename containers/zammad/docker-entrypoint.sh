#!/bin/bash

set -e

function check_install_update_ready {
  until [ -f "${INSTALL_UPDATE_READY_FILE}" ]; then
    echo "waiting for install or update to be ready..."
    sleep 5
  done
}

function mount_nfs {
  if [ -n "$(env|grep KUBERNETES)" ]; then
    test -d ${ZAMMAD_DIR} || mkdir -p ${ZAMMAD_DIR}
    mount -t nfs4 zammad-nfs:/ /opt/zammad
  fi
}

# zammad init
if [ "$1" = 'zammad-init' ]; then
  # wait for postgres process coming up on zammad-postgresql
  until (echo > /dev/tcp/zammad-postgresql/5432) &> /dev/null; do
    echo "zammad railsserver waiting for postgresql server to be ready..."
    sleep 5
  done

  mount_nfs

  # install / update zammad
  rsync -a --delete --exclude 'storage/fs/*' ${ZAMMAD_TMP_DIR}/ ${ZAMMAD_DIR}

  echo "initialising / updating database..."
  # db mirgrate
  set +e
  bundle exec rake db:migrate &> /dev/null
  DB_CHECK="$?"
  set -e

  if [ "${DB_CHECK}" != "0" ]; then
    bundle exec rake db:create
    bundle exec rake db:migrate
    bundle exec rake db:seed
  fi

  echo "changing settings..."
  # es config
  bundle exec rails r "Setting.set('es_url', 'http://zammad-elasticsearch:9200')"

  echo "rebuilding es searchindex..."
  bundle exec rake searchindex:rebuild

  # chown everything to zammad user
  chown -R ${ZAMMAD_USER}:${ZAMMAD_USER} ${ZAMMAD_DIR}

  # create install ready file
  touch ${INSTALL_UPDATE_READY_FILE}
fi


# zammad nginx
if [ "$1" = 'zammad-nginx' ]; then
  check_install_update_ready

  mount_nfs

  echo "starting nginx..."

  if [ -n "$(env|grep KUBERNETES)" ]; then
    sed -i -e 's#server zammad-railsserver:3000#server zammad:3000#g' -e 's#zammad-websocket:6042#zammad:6042#g' /etc/nginx/sites-enabled/default
  fi

  exec /usr/sbin/nginx -g 'daemon off;'
fi


# zammad-railsserver
if [ "$1" = 'zammad-railsserver' ]; then
  check_install_update_ready

  mount_nfs

  echo "starting railsserver..."

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec puma -b tcp://0.0.0.0:3000 -e ${RAILS_ENV}
fi


# zammad-scheduler
if [ "$1" = 'zammad-scheduler' ]; then
  check_install_update_ready

  mount_nfs

  echo "starting scheduler..."

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/scheduler.rb run
fi


# zammad-websocket
if [ "$1" = 'zammad-websocket' ]; then
  check_install_update_ready

  mount_nfs

  echo "starting websocket server..."

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/websocket-server.rb -b 0.0.0.0 start
fi
