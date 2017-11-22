#!/bin/bash

set -e

function check_railsserver_available {
  # wait for zammad process coming up
  until (echo > /dev/tcp/zammad-railsserver/3000) &> /dev/null; do
    echo "waiting for zammads railsserver to be ready..."
    sleep 2
  done
}

function check_nfs_available {
  until (echo > /dev/tcp/zammad-nfs/2049) &> /dev/null; do
    echo "waiting for zammads nfsserver to be ready..."
    sleep 2
  done
}

function mount_nfs {
  if [ -n "$(env|grep KUBERNETES)" ]; then
    check_nfs_available
    test -d ${ZAMMAD_DIR}/tmp || mkdir -p ${ZAMMAD_DIR}/tmp
    mount -t nfs4 zammad-nfs:/ ${ZAMMAD_DIR}/tmp
  fi
}

# zammad-railsserver
if [ "$1" = 'zammad-railsserver' ]; then

  # wait for postgres process coming up on zammad-postgresql
  until (echo > /dev/tcp/zammad-postgresql/5432) &> /dev/null; do
    echo "waiting for postgresql server to be ready..."
    sleep 5
  done

  echo "railsserver can access postgresql server now..."

  mount_nfs

  cd ${ZAMMAD_DIR}

  # db mirgrate
  set +e
  bundle exec rake db:migrate &> /dev/null
  DB_CHECK="$?"
  set -e

  if [ "${DB_CHECK}" != "0" ]; then
    echo "creating db & searchindex..."
    bundle exec rake db:create
    bundle exec rake db:migrate
    bundle exec rake db:seed
  fi

  # es config
  bundle exec rails r "Setting.set('es_url', 'http://zammad-elasticsearch:9200')"
  bundle exec rake searchindex:rebuild

  # disable storage setting in admin backend
  bundle exec rails r "setting = Setting.find_by(name: 'storage_provider');setting.preferences[:permission] = ['admin_not_existing_permission'];setting.save!"

  # chown everything to zammad user
  chown -R ${ZAMMAD_USER}:${ZAMMAD_USER} ${ZAMMAD_DIR}

  # run zammad
  echo "starting zammad..."

  if [ "${RAILS_SERVER}" == "puma" ]; then
    exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec puma -b tcp://0.0.0.0:3000 -e ${RAILS_ENV}
  fi
fi


# zammad-scheduler
if [ "$1" = 'zammad-scheduler' ]; then
  check_railsserver_available

  echo "scheduler can access raillsserver now..."

  mount_nfs

  # start scheduler
  cd ${ZAMMAD_DIR}
  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/scheduler.rb run
fi


# zammad-websocket
if [ "$1" = 'zammad-websocket' ]; then
  check_railsserver_available

  echo "websocket server can access raillsserver now..."

  mount_nfs

  cd ${ZAMMAD_DIR}
  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/websocket-server.rb -b 0.0.0.0 start
fi

# zammad nginx
if [ "$1" = 'zammad-nginx' ]; then
  /usr/sbin/nginx -g 'daemon off;'
fi
