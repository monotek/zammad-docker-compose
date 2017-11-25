#!/bin/bash

set -e

# zammad init
if [ "$1" = 'zammad-init' ]; then
  # wait for postgres process coming up on zammad-postgresql
  until (echo > /dev/tcp/zammad-postgresql/5432) &> /dev/null; do
    echo "zammad railsserver waiting for postgresql server to be ready..."
    sleep 5
  done

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
  # disable storage setting in admin backend
  #bundle exec rails r "setting = Setting.find_by(name: 'storage_provider');setting.preferences[:permission] = ['admin_not_existing_permission'];setting.save!"

  echo "rebuilding es searchindex..."
  bundle exec rake searchindex:rebuild

  # chown everything to zammad user
  chown -R ${ZAMMAD_USER}:${ZAMMAD_USER} ${ZAMMAD_DIR}
fi


# zammad nginx
if [ "$1" = 'zammad-nginx' ]; then
  echo "starting nginx..."

  if [ -n "$(env|grep KUBERNETES)" ]; then
    sed -i -e 's#server zammad-railsserver:3000#server zammad:3000#g' -e 's#zammad-websocket:6042#zammad:6042#g' /etc/nginx/sites-enabled/default
  fi

  exec /usr/sbin/nginx -g 'daemon off;'
fi


# zammad-railsserver
if [ "$1" = 'zammad-railsserver' ]; then
  echo "starting railsserver..."

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec puma -b tcp://0.0.0.0:3000 -e ${RAILS_ENV}
fi


# zammad-scheduler
if [ "$1" = 'zammad-scheduler' ]; then
  echo "starting scheduler..."

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/scheduler.rb run
fi


# zammad-websocket
if [ "$1" = 'zammad-websocket' ]; then
  echo "starting websocket server..."

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/websocket-server.rb -b 0.0.0.0 start
fi
