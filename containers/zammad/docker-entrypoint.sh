#!/bin/bash

set -e

function check_railsserver_available {
  # wait for zammad process coming up
  until (echo > /dev/tcp/zammad-railsserver/3000) &> /dev/null; do
    echo "waiting for zammads railsserver to be ready..."
    sleep 5
  done
}

function check_zammad_ready {
  until [ -f "${ZAMMAD_READY_FILE}" ]; then
    echo "waiting for install or update to be ready..."
    sleep 5
  done
}

function mount_nfs {
  if [ -n "$(env|grep KUBERNETES)" ]; then
    test -d ${ZAMMAD_DIR} || mkdir -p ${ZAMMAD_DIR}
    mount -t nfs4 zammad-nfs:/data /opt/zammad
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
  rsync -a --delete --exclude 'storage/fs/*' --exclude 'public/assets/images/*' ${ZAMMAD_TMP_DIR}/ ${ZAMMAD_DIR}
  rsync -a ${ZAMMAD_TMP_DIR}/public/assets/images/ ${ZAMMAD_DIR}/public/assets/images

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
  echo "zammad-init" > ${ZAMMAD_READY_FILE}
fi


# zammad nginx
if [ "$1" = 'zammad-nginx' ]; then
  check_railsserver_available

  mount_nfs

  if [ -n "$(env|grep KUBERNETES)" ]; then
    sed -i -e 's#server zammad-railsserver:3000#server zammad:3000#g' -e 's#zammad-websocket:6042#zammad:6042#g' /etc/nginx/sites-enabled/default
  fi

  until [ -n "$(grep zammad-railsserver < ${ZAMMAD_READY_FILE})" ] && [ -n "$(grep zammad-scheduler < ${ZAMMAD_READY_FILE})" ] && [ -n "$(grep zammad-websocket < ${ZAMMAD_READY_FILE})" ] ; do
    echo "nginx waiting for all zammad services to start..."
    sleep 5
  done

  rm ${ZAMMAD_READY_FILE}

  echo "starting nginx..."

  exec /usr/sbin/nginx -g 'daemon off;'
fi


# zammad-railsserver
if [ "$1" = 'zammad-railsserver' ]; then
  check_zammad_ready

  mount_nfs

  echo "starting railsserver..."

  echo "zammad-railsserver" >> ${ZAMMAD_READY_FILE}

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec puma -b tcp://0.0.0.0:3000 -e ${RAILS_ENV}
fi


# zammad-scheduler
if [ "$1" = 'zammad-scheduler' ]; then
  check_zammad_ready

  mount_nfs

  echo "starting scheduler..."

  echo "zammad-scheduler" >> ${ZAMMAD_READY_FILE}

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/scheduler.rb run
fi


# zammad-websocket
if [ "$1" = 'zammad-websocket' ]; then
  check_zammad_ready

  mount_nfs

  echo "starting websocket server..."

  echo "zammad-websocket" >> ${ZAMMAD_READY_FILE}

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/websocket-server.rb -b 0.0.0.0 start
fi
