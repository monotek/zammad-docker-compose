#!/bin/bash

set -e

function check_zammad_ready {
  until [ -f "${ZAMMAD_READY_FILE}" ]; do
    echo "waiting for install or update to be ready..."
    sleep 5
  done
}

function mount_nfs {
  if [ -n "$(env|grep KUBERNETES)" ]; then
    test -d ${ZAMMAD_DIR} || mkdir -p ${ZAMMAD_DIR}
    mount -t nfs4 zammad-nfs:/data /opt/zammad
    chown ${ZAMMAD_USER}:${ZAMMAD_USER} ${ZAMMAD_DIR}
  fi
}

# zammad init
if [ "$1" = 'zammad-init' ]; then
  until (echo > /dev/tcp/zammad-postgresql/5432) &> /dev/null; do
    echo "zammad railsserver waiting for postgresql server to be ready..."
    sleep 5
  done

  mount_nfs

  # install / update zammad
  rsync -a --delete --exclude 'storage/fs/*' --exclude 'public/assets/images/*' ${ZAMMAD_TMP_DIR}/ ${ZAMMAD_DIR}
  rsync -a ${ZAMMAD_TMP_DIR}/public/assets/images/ ${ZAMMAD_DIR}/public/assets/images

  cd ${ZAMMAD_DIR}

  # enable memcached
  sed -i -e "s/.*config.cache_store.*file_store.*cache_file_store.*/    config.cache_store = :dalli_store, 'zammad-memcached:11211'\n    config.session_store = :dalli_store, 'zammad-memcached:11211'/" config/application.rb

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

  until (echo > /dev/tcp/zammad-elasticsearch/9200) &> /dev/null; do
    echo "zammad railsserver waiting for elasticsearch server to be ready..."
    sleep 5
  done

  echo "rebuilding es searchindex..."
  bundle exec rake searchindex:rebuild

  # chown everything to zammad user
  chown -R ${ZAMMAD_USER}:${ZAMMAD_USER} ${ZAMMAD_DIR}

  # create install ready file
  su -c "echo 'z0ammad-init' > ${ZAMMAD_READY_FILE}" ${ZAMMAD_USER}
fi


# zammad nginx
if [ "$1" = 'zammad-nginx' ]; then
  mount_nfs

  if [ -n "$(env|grep KUBERNETES)" ]; then
    sed -i -e 's#server zammad-\(railsserver\|websocket\):#server zammad:#g' /etc/nginx/sites-enabled/default
  fi

  until [ -f "${ZAMMAD_READY_FILE}" ] && [ -n "$(grep zammad-railsserver < ${ZAMMAD_READY_FILE})" ] && [ -n "$(grep zammad-scheduler < ${ZAMMAD_READY_FILE})" ] && [ -n "$(grep zammad-websocket < ${ZAMMAD_READY_FILE})" ] ; do
    echo "waiting for all zammad services to start..."
    sleep 5
  done

  rm ${ZAMMAD_READY_FILE}

  echo "starting nginx..."

  exec /usr/sbin/nginx -g 'daemon off;'
fi


# zammad-railsserver
if [ "$1" = 'zammad-railsserver' ]; then
  mount_nfs

  check_zammad_ready

  echo "starting railsserver..."

  echo "zammad-railsserver" >> ${ZAMMAD_READY_FILE}

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec puma -b tcp://0.0.0.0:3000 -e ${RAILS_ENV}
fi


# zammad-scheduler
if [ "$1" = 'zammad-scheduler' ]; then
  mount_nfs

  check_zammad_ready

  echo "starting scheduler..."

  echo "zammad-scheduler" >> ${ZAMMAD_READY_FILE}

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/scheduler.rb run
fi


# zammad-websocket
if [ "$1" = 'zammad-websocket' ]; then
  mount_nfs

  check_zammad_ready

  echo "starting websocket server..."

  echo "zammad-websocket" >> ${ZAMMAD_READY_FILE}

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/websocket-server.rb -b 0.0.0.0 start
fi
