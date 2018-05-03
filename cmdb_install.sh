#/bin/bash
cd /opt/
#该脚本可能会更改系统软件版本 请在新装centos/7上测试

#请勿重复运行 运行时请使用root
eip=`python -c "import socket
try:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.connect(('8.8.8.8', 80))
    ip = s.getsockname()[0]
finally:
    s.close()
print ip
"`
echo "已获取当前服务器ip为:" $eip

read -p "请输入redis 服务密码（必须）" redispass

echo -e "\n"

read -p "请输入mongo用户名（必须）" mongouser

echo -e "\n"

read -p "请输入mongo密码（必须）" mongopass

echo "[mongodb-org-3.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/\$releasever/mongodb-org/3.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.2.asc" > /etc/yum.repos.d/mongodb-prg-3.2.repo

yum install wget vim java-1.7.0-openjdk git golang gcc gcc-c++ kernel-devel mongodb-org -y

sleep 1s

yum group install "Development Tools" -y

sleep 1s 

wget https://media.githubusercontent.com/media/Nevss/bk_cmdb_install/master/redis-3.2.11.tar.gz?raw=true && tar xf redis-3.2.11.tar.gz
wget https://media.githubusercontent.com/media/Nevss/bk_cmdb_install/master/zookeeper-3.4.12.tar.gz?raw=true && tar xf zookeeper-3.4.11.tar.gz
wget https://media.githubusercontent.com/media/Nevss/bk_cmdb_install/master/cmdb-3.0.6.tar.gz?raw=true && tar xf cmdb-3.0.6.tar.gz

wget https://github.com/Nevss/bk_cmdb_install/blob/master/node-v4.5.0.tar.gz?raw=true && tar xf node-v4.5.0.tar.gz

sleep 1s 

make -C redis-3.2.11 

./node-v4.5.0/configure

sleep 1s 
make -C node-v4.5.0

sleep 1s 

make -C node-v4.5.0 install

sleep 1s


echo "# The number of milliseconds of each tick
tickTime=2000
# The number of ticks that the initial
# synchronization phase can take
initLimit=10
# The number of ticks that can pass between
# sending a request and getting an acknowledgement
syncLimit=5
# the directory where the snapshot is stored.
# do not use /tmp for storage, /tmp here is just
# example sakes.
dataDir=/datatmp/zookeeper/data
dataLogDir=/datatmp/zookeeper/logs
# the port at which the clients will connect
clientPort=2181
# the maximum number of client connections.
# increase this if you need to handle more clients
#maxClientCnxns=60
#
# Be sure to read the maintenance section of the
# administrator guide before turning on autopurge.
#
# http://zookeeper.apache.org/doc/current/zookeeperAdmin.html#sc_maintenance
#
# The number of snapshots to retain in dataDir
#autopurge.snapRetainCount=3
# Purge task interval in hours
# Set to "0" to disable auto purge feature
#autopurge.purgeInterval=1

server.1=$eip:2888:3888
"  > ./zookeeper-3.4.11/conf/zoo.cfg
sed -i '$a\export ZOOKEERPER_HOME=/opt/zookeeper-3.4.11' /etc/profile
sed -i '$a\export PATH=$ZOOKEEPER_HOME/bin:$PATH' /etc/profile
sed -i '$a\export PATH' /etc/profile
mkdir -p /datatmp/zookeeper/data/
mkdir /datatmp/zookeeper/logs
echo "1" > /datatmp/zookeeper/data/myid

sed -i "s/127.0.0.1/$eip/g" /etc/mongod.conf


sed -i "s/bind 127.0.0.1/bind $eip/g" ./redis-3.2.11/redis.conf
sed -i 's/protected-mode yes/protected-mode no/g' ./redis-3.2.11/redis.conf
sed -i "\$a\requirepass $redispass" ./redis-3.2.11/redis.conf
sed -i "s/daemonize no/daemonize yes/g" ./redis-3.2.11/redis.conf
./redis-3.2.11/src/redis-server ./redis-3.2.11/redis.conf &

sleep 2s

service mongod start

sleep 2s

./zookeeper-3.4.11/bin/zkServer.sh start &

sleep 2s

mongo $eip/cmdb --eval "db.createUser({user: '$mongouser',pwd: '$mongopass',roles: [ { role: 'readWrite', db: 'cmdb' } ]})"

echo '#!/bin/bash
# chkconfig: 2345 10 90
# description: Start and Stop redis

# Simple Redis init.d script conceived to work on Linux systems
# as it does use of the /proc filesystem.

REDISPORT=6379
EXEC=/opt/redis-3.2.11/src/redis-server
CLIEXEC=/opt/redis-3.2.11/src/redis-cli

PIDFILE=/var/run/redis_${REDISPORT}.pid
#CONF="/etc/redis/${REDISPORT}.conf"
CONF="/opt/redis-3.2.11/redis.conf"

case "$1" in
    start)
        if [ -f $PIDFILE ]
        then
                echo "$PIDFILE exists, process is already running or crashed"
        else
                echo "Starting Redis server..."
                $EXEC $CONF
        fi
        ;;
    stop)
        if [ ! -f $PIDFILE ]
        then
                echo "$PIDFILE does not exist, process is not running"
        else
                PID=$(cat $PIDFILE)
                echo "Stopping ..."
                $CLIEXEC -p $REDISPORT shutdown
                while [ -x /proc/${PID} ]
                do
                    echo "Waiting for Redis to shutdown ..."
                    sleep 1
                done
                echo "Redis stopped"
        fi
        ;;
    *)
        echo "Please use start or stop as first argument"
        ;;
esac' > /etc/init.d/redis

chmod +x /etc/init.d/redis

chkconfig --add redis 

chkconfig redis on

echo '#!/bin/bash
#chkconfig: 2345 10 90
#description: service zookeeper


case  "$1"   in
          start)  su  root   opt/zookeeper-3.4.11/bin/zkServer.sh   start;;
          start-foreground)  su  root  opt/zookeeper-3.4.11/bin/zkServer.sh    start-foreground;;
          stop)  su  root   opt/zookeeper-3.4.11/bin/zkServer.sh   stop;;
          status)  su root  opt/zookeeper-3.4.11/bin/zkServer.sh    status;;
          restart)  su root   opt/zookeeper-3.4.11/bin/zkServer.sh   restart;;
          upgrade)su root   opt/zookeeper-3.4.11/bin/zkServer.sh   upgrade;;
          print-cmd)su root   opt/zookeeper-3.4.11/bin/zkServer.sh   print-cmd;;
          *)  echo  "requirestart|start-foreground|stop|status|restart|print-cmd";;
esac' > /etc/init.d/zookeeper

chmod +x /etc/init.d/zookeeper

chkconfig --add zookeeper

chkconfig zookeeper on

chkconfig --add mongod

chkconfig mongod on

echo '#/bin/bash
/opt/cmdb/start.sh' > start_cmdb.sh

chmod +x start_cmdb.sh

echo '#/bin/bash
/opt/cmdb/init_db.sh' > init_db.sh

chmod +x init_db.sh

echo '#/bin/bash
/opt/cmdb/stop.sh' > stop.sh

cd ./cmdb

python init.py  --discovery $eip:2181 --database cmdb --redis_ip $eip --redis_port 6379 --redis_pass $redispass --mongo_ip $eip --mongo_port 27017 --mongo_user $mongouser --mongo_pass $mongopass --blueking_cmdb_url http://$eip:8088 --blueking_paas_url http://$eip:8088

sleep 2s



echo "install ok! reboot to use!  Created by Sven"
