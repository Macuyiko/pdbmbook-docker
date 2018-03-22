#!/bin/bash
set -m

service mysql start
service apache2 start

nohup mongod --bind_ip 127.0.0.1 --auth --quiet &

RET=1
while [[ RET -ne 0 ]]; do
    echo "=> Waiting for confirmation of MongoDB service startup"
    sleep 5
    mongo --eval "help" >/dev/null 2>&1
    RET=$?
done

if [ ! -f /data/db/.mongodb_password_set ]; then
    mongo admin --eval "db.createUser({user: \"admin\", pwd: \"adminroot\", roles: [ { role: \"userAdminAnyDatabase\", db: \"admin\" } ]  })"
    touch /data/db/.mongodb_password_set
fi

rm /var/www/html/index.html

dos2unix /var/www/html/lib/hbase-1.3.1/bin/hbase
dos2unix /var/www/html/lib/hbase-1.3.1/bin/*.sh
dos2unix /var/www/html/lib/hbase-1.3.1/bin/test/*.sh
dos2unix /var/www/html/lib/hbase-1.3.1/conf/*.sh

/var/www/html/lib/hbase-1.3.1/bin/start-hbase.sh

echo ""
echo ""
echo "-------------------------------------------------------"
echo "You can now open a Web Browser to access the playground"
echo "This window will start showing debug output..."
echo "-------------------------------------------------------"

sleep 30

tail -f /var/log/apache2/access.log & tail -f /var/log/apache2/error.log

