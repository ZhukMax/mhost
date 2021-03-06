#!/bin/bash

function delete() {
	echo "Enter project name for delete:"
	read USERNAME

	echo "Enter DataBase root password:"
	read -s ROOTPASS
	
	mysql -uroot --password=$ROOTPASS -e "DROP USER $USERNAME@localhost"
	mysql -uroot --password=$ROOTPASS -e "DROP DATABASE $USERNAME"
	
	rm -f /etc/nginx/sites-enabled/$USERNAME.conf
	rm -f /etc/nginx/sites-available/$USERNAME.conf
	rm -rf /var/www/$USERNAME

	service nginx restart
	service php7.0-fpm restart
}

# Keys for script
while [ 1 ] ; do 
   if [ "$1" = "--blank" ] ; then 
      PROJECT="b" 
   elif [ "$1" = "-b" ] ; then 
      PROJECT="b"
   elif [ "$1" = "--new" ] ; then 
      PROJECT="n" 
   elif [ "$1" = "-n" ] ; then 
      PROJECT="n"
   elif [ "$1" = "--exists" ] ; then 
      PROJECT="x" 
   elif [ "$1" = "-x" ] ; then 
      PROJECT="x"
   elif [ "$1" = "--delete" ] ; then
      delete
      exit 15
   elif [ -z "$1" ] ; then 
      break
   else 
      echo "Error: unknown key" 1>&2 
      exit 1 
   fi 
   shift 
done

echo "Enter username for site and database:"
read USERNAME
 
echo "Enter domain"
read DOMAIN

mkdir /var/www/$USERNAME
mkdir /var/www/$USERNAME/tmp
mkdir /var/www/$USERNAME/logs

if [ $PROJECT = x ]
then
	cd /var/www/$USERNAME
	echo "Enter url to your git-repository:"
	read REPO
	git clone $REPO
	cd ~
else
	mkdir /var/www/$USERNAME/public
fi

chmod -R 755 /var/www/$USERNAME/
chown -R www-data:www-data /var/www/$USERNAME

echo "Creating vhost file"
echo "
server {
	listen				80;
	server_name			$DOMAIN www.$DOMAIN;
	root				/var/www/$USERNAME/public;
	access_log			/var/www/$USERNAME/logs/access.log;
	error_log			/var/www/$USERNAME/logs/error.log;
	index				index.php index.html;
	rewrite_log			on;
	
	if (\$host != '$DOMAIN' ) {
		rewrite			^/(.*)$  http://$DOMAIN/\$1  permanent;
	}
	location ~* ^/core/ {
		deny			all;
	}
	location / {
		try_files		\$uri \$uri/ @rewrite;
	}
	location /index.html {
		rewrite			/ / permanent;
	}
 
	location ~ ^/(.*?)/index\.html$ {
		rewrite			^/(.*?)/ /$1/ permanent;
	}
	location @rewrite {
		rewrite			^/(.*)$ /index.php?q=\$1;
	}
	location ~ \.php$ {
		include			fastcgi_params;
		fastcgi_param	SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		fastcgi_pass	unix:/var/run/php/php7.0-fpm.sock;
	}
	location ~* ^.+\.(jpg|jpeg|gif|css|png|js|ico|bmp)$ {
	   access_log		off;
	   expires			10d;
	   break;
	}
	location ~ /\.ht {
		deny			all;
	}
}
" > /etc/nginx/sites-available/$USERNAME.conf
ln -s /etc/nginx/sites-available/$USERNAME.conf /etc/nginx/sites-enabled/$USERNAME.conf

service php7.0-fpm restart
echo "php7.0-fpm restart"
service nginx restart
echo "nginx restart"

echo "Enter MySQL root password:"
read -s ROOTPASS

echo "Enter password for new DB:"
read -s MYSQLPASS

echo "Creating database"

Q1="CREATE DATABASE IF NOT EXISTS $USERNAME DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;;"
Q2="GRANT ALTER,DELETE,DROP,CREATE,INDEX,INSERT,SELECT,UPDATE,CREATE TEMPORARY TABLES,LOCK TABLES ON $USERNAME.* TO '$USERNAME'@'localhost' IDENTIFIED BY '$MYSQLPASS';"
Q3="FLUSH PRIVILEGES;"
SQL="${Q1}${Q2}${Q3}"
	
mysql -uroot --password=$ROOTPASS -e "$SQL"
