#!/bin/bash

DOCKER_LEMP_DIR="/home/maximillian/docker-lemp/"
USER="maximillian:maximillian"
MYSQL_CONTAINER="docker-lemp_mysql_1"
PHP_CONTAINER="docker-lemp_php_1"
siteName=""
dbName=""

if [ -n "$1" ]
then
  siteName=$1;
  dbName=$(echo $siteName | sed -e 's/[\.-]/_/g')
else
  echo "No site name found.";
  exit 0;
fi
sitePath=$DOCKER_LEMP_DIR/www/$siteName

cd $sitePath &&
git pull &&
composer install &&
sudo chown -R $USER ./* && sudo chmod -R 777 ./* && git config core.fileMode false &&

echo ---------------------------------------------------------------------------- &&
echo Updating site config &&
CONF=$sitePath/common/config/main-local.php
if test -f "$CONF"; then
  echo Config already exists
else
  ./init &&
  sed -i \
    -e "s/mysql:host=localhost/mysql:host=mysql/g" \
    -e "s/dbname=.*'/dbname=${dbName}'/g" \
    -e "s/'localhost'/'redis'/g" \
    -e "s/'password' => ''/'password' => 'root'/g" \
    $CONF
fi

echo ---------------------------------------------------------------------------- &&
echo Creating database &&
docker exec -it $MYSQL_CONTAINER mysql -u root --password='root' -e \
"CREATE DATABASE IF NOT EXISTS ${dbName}" &&
echo database $dbName created &&

echo ---------------------------------------------------------------------------- &&
echo Running Migrations &&
docker exec -it $PHP_CONTAINER bash -c "cd /var/www/${siteName} && php yii migrate" &&

echo ---------------------------------------------------------------------------- &&
echo Updating Nginx config &&
cd $DOCKER_LEMP_DIR/config/nginx &&
sed "s/SITE_NAME/${siteName}/g" template.conf > $dbName.conf &&

echo ---------------------------------------------------------------------------- &&
echo Updating /etc/hosts &&
if grep $siteName /etc/hosts
then
  echo "$siteName already exists"
else
  echo "Adding $siteName to /etc/hosts";
  sudo -- sh -c -e "echo 127.0.0.1 local.${siteName} >> /etc/hosts";
  if  grep $siteName /etc/hosts
  then echo "$siteName was added succesfully";
  else
    echo "Failed to Add $siteName";
  fi
fi &&

echo ---------------------------------------------------------------------------- &&
echo Restarting Docker-LEMP &&
cd $DOCKER_LEMP_DIR &&
docker stop $(sudo docker ps -aq) &&
docker-compose start &&

echo ---------------------------------------------------------------------------- &&
echo Installing assets &&
cd $sitePath/frontend/themes &&
cd $(ls -d */|head -n 1)/resources &&
npm i &&
npm run build

