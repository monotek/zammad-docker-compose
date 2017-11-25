#!/bin/bash

set -e

# zammad-railsserver
if [ "$1" = 'zammad-railsserver' ]; then
  echo "starting zammad..."

  if [ "${RAILS_SERVER}" == "puma" ]; then
    exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec puma -b tcp://0.0.0.0:3000 -e ${RAILS_ENV}
  fi
fi


# zammad-scheduler
if [ "$1" = 'zammad-scheduler' ]; then
  echo "scheduler can access raillsserver now..."

  # start scheduler
  cd ${ZAMMAD_DIR}
  exec gosu ${Zzammad-nginx-59f68b57f-j6v4jAMMAD_USER}:${ZAMMAD_USER} bundle exec script/scheduler.rb run
fi


# zammad-websocket
if [ "$1" = 'zammad-websocket' ]; then
  echo "starting websocket server"

  exec gosu ${ZAMMAD_USER}:${ZAMMAD_USER} bundle exec script/websocket-server.rb -b 0.0.0.0 start
fi

# zammad nginx
if [ "$1" = 'zammad-nginx' ]; then
  echo "starting nginx"

  if [ -n "$(env|grep KUBERNETES)" ]; then
    sed -i -e 's#server zammad-railsserver:3000#server zammad:3000#g' -e 's#zammad-websocket:6042#zammad:6042#g' /etc/nginx/sites-enabled/default
  fi

  exec /usr/sbin/nginx -g 'daemon off;'
fi

if [ "$1" = 'zammad-init' ]; then
  function check_railsserver_available {
    # wait for zammad process coming up
    until (echo > /dev/tcp/zammad-railsserver/3000) &> /dev/null; do
      echo "waiting for zammads railsserver to be ready..."
      sleep 2
    done
  }

  echo "initialising database"

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

  echo "changing settings..."
  # es config
  bundle exec rails r "Setting.set('es_url', 'http://zammad-elasticsearch:9200')"
  bundle exec rake searchindex:rebuild

  # disable storage setting in admin backend
  #bundle exec rails r "setting = Setting.find_by(name: 'storage_provider');setting.preferences[:permission] = ['admin_not_existing_permission'];setting.save!"

  # chown everything to zammad user
  chown -R ${ZAMMAD_USER}:${ZAMMAD_USER} ${ZAMMAD_DIR}

fi
