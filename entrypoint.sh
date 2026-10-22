#!/bin/bash
set -m

export JAVA_HOME=/usr
# Keep the embedded HBase heap modest; the default 1 GB is heavy for a
# Docker Desktop / laptop environment.
export HBASE_HEAPSIZE=512

# --- MySQL ---------------------------------------------------------------
# Ubuntu 26.04's MySQL package no longer ships /etc/init.d/mysql, so start
# mysqld directly. The data directory is initialized when the image is built.
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld
# Apache (www-data) connects through the socket.
chmod 755 /var/run/mysqld
nohup /usr/sbin/mysqld --user=mysql >/var/log/mysql/mysqld.out 2>&1 &

for i in $(seq 1 30); do
    mysqladmin ping --silent >/dev/null 2>&1 && break
    sleep 1
done
if ! mysqladmin ping --silent >/dev/null 2>&1; then
    echo "MySQL did not start; see /var/log/mysql/mysqld.out" >&2
    tail -20 /var/log/mysql/mysqld.out >&2 || true
    exit 1
fi

# The standalone configuration.php connects as root/root. Ubuntu initializes
# root with auth_socket, so give it a password the app can use. MySQL 8.4
# disables mysql_native_password; caching_sha2_password is the default and is
# supported by PHP's mysqlnd.
if ! mysql -uroot <<'SQL'
ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'root';
FLUSH PRIVILEGES;
SQL
then
    echo "Could not set the MySQL root password" >&2
    exit 1
fi

if ! mysql -uroot -proot -e "SELECT 1" >/dev/null 2>&1; then
    echo "MySQL root password authentication failed" >&2
    exit 1
fi

service apache2 start

# --- MongoDB -------------------------------------------------------------
mkdir -p /data/db
nohup mongod --bind_ip 127.0.0.1 --auth --quiet >/var/log/mongod.log 2>&1 &

RET=1
while [[ RET -ne 0 ]]; do
    echo "=> Waiting for MongoDB to start"
    sleep 2
    mongosh --quiet --eval "db.adminCommand({ping:1})" >/dev/null 2>&1
    RET=$?
done

if [ ! -f /data/db/.mongodb_password_set ]; then
    mongosh --quiet --eval \
        'db.getSiblingDB("admin").createUser({user:"admin", pwd:"playground", roles:[{role:"userAdminAnyDatabase", db:"admin"}]})'
    touch /data/db/.mongodb_password_set
fi

# --- HBase (bundled 1.3.1, standalone) -----------------------------------
dos2unix /var/www/html/lib/hbase-1.3.1/bin/hbase >/dev/null 2>&1 || true
dos2unix /var/www/html/lib/hbase-1.3.1/bin/*.sh >/dev/null 2>&1 || true
dos2unix /var/www/html/lib/hbase-1.3.1/bin/test/*.sh >/dev/null 2>&1 || true
dos2unix /var/www/html/lib/hbase-1.3.1/conf/*.sh >/dev/null 2>&1 || true

/var/www/html/lib/hbase-1.3.1/bin/start-hbase.sh

echo ""
echo "-------------------------------------------------------"
echo "The playground is starting. Open http://localhost:8081"
echo "(Apache, MySQL, MongoDB and HBase are being started)"
echo "-------------------------------------------------------"
echo ""

sleep 5
tail -f /var/log/apache2/access.log /var/log/apache2/error.log
