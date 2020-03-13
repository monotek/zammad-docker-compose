#!/bin/bash
#
# run zammad tests
#

set -o errexit
set -o pipefail

docker-compose logs --timestamps --follow &

until (curl -I --silent --fail localhost | grep -iq "HTTP/1.1 200 OK"); do
    echo "wait for zammad to be ready..."
    sleep 15
done

sleep 30

echo
echo "Success - Zammad is up :)"
echo
echo "Execute autowizard..."
echo
docker exec zammad-docker-compose_zammad-railsserver_1 rake zammad:setup:auto_wizard
echo 
echo "Autowizard executed successful :)"
echo 
echo "Fill DB with some random data"
docker exec zammad-docker-compose_zammad-railsserver_1 rails r "FillDB.load(agents: 1,customers: 1,groups: 1,organizations: 1,overviews: 1,tickets: 1)"
echo
echo "DB fill successful :)"
echo


echo
echo "create user via api"
echo
docker exec zammad-docker-compose_zammad-nginx_1 curl -I localhost

docker exec zammad-docker-compose_zammad-nginx_1 curl --cookie --silent --fail --show-error -u info@zammad.org:Zammad -H "Content-Type: application/json" -X POST -d '{"firstname":"Bob","lastname":"Smith","email":"testuser@example.com","roles":["Customer"],"password":"some_password"}' 'http://localhost/api/v1/users'

# #curl --cookie --silent --fail --show-error -u info@zammad.org:Zammad -H "Content-Type: application/json" -X POST -d '{"firstname":"Bob","lastname":"Smith","email":"testuser@example.com","roles":["Customer"],"password":"some_password"}' 'http://localhost/api/v1/users'

# echo
# echo "create user successful :)"
# echo

# echo 
# echo "search user"
# echo
# curl --silent --fail --show-error -u info@zammad.org:Zammad "http://$(docker inspect zammad-docker-compose_zammad-nginx_1 | grep '"IPAddress": "[0-9]*\.[0-9]*\.[0-9]\.[0-9]*' | sed -e 's#.*: "##g' -e 's#",##g')/api/v1/users/search?query=Smith&limit=10&expand=true"

# echo
# echo "search user successful :)"
# echo

# echo
# echo "create ticket"
# echo
# curl --silent --fail --show-error -u info@zammad.org:Zammad -H "Content-Type: application/json" -X POST -d '{"title":"Help me!","group": "Users","article":{"subject":"some subject","body":"some message","type":"note","internal":false},"customer":"testuser@example.com","note": "some note"}' 'http://localhost/api/v1/tickets'

# echo
# echo "create ticket successful :)"
# echo



