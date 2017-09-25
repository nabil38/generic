#!/bin/bash

# Disable Strict Host checking for non interactive git clones

mkdir -p -m 0700 /root/.ssh
echo -e "Host *\n\tStrictHostKeyChecking no\n" >> /root/.ssh/config

if [ ! -z "$SSH_KEY" ]; then
 echo $SSH_KEY > /root/.ssh/id_rsa.base64
 base64 -d /root/.ssh/id_rsa.base64 > /root/.ssh/id_rsa
 chmod 600 /root/.ssh/id_rsa
fi

# Setup git variables
if [ ! -z "$GIT_EMAIL" ]; then
 git config --global user.email "$GIT_EMAIL"
fi
if [ ! -z "$GIT_NAME" ]; then
 git config --global user.name "$GIT_NAME"
 git config --global push.default simple
fi

# Enable custom nginx config files if they exist
if [ -f /var/www/html/conf/nginx/nginx-site.conf ]; then
  cp /var/www/html/conf/nginx/nginx-site.conf /etc/nginx/sites-available/default.conf
fi

if [ -f /var/www/html/conf/nginx/nginx-site-ssl.conf ]; then
  cp /var/www/html/conf/nginx/nginx-site-ssl.conf /etc/nginx/sites-available/default-ssl.conf
fi

# Display PHP error's or not
if [[ "$ERRORS" != "1" ]] ; then
 echo php_flag[display_errors] = off >> /etc/php5/php-fpm.conf
else
 echo php_flag[display_errors] = on >> /etc/php5/php-fpm.conf
fi

# Display Version Details or not
if [[ "$HIDE_NGINX_HEADERS" == "0" ]] ; then
 sed -i "s/server_tokens off;/server_tokens on;/g" /etc/nginx/nginx.conf
else
 sed -i "s/expose_php = On/expose_php = Off/g" /etc/php5/conf.d/php.ini
fi

# Increase the memory_limit
if [ ! -z "$PHP_MEM_LIMIT" ]; then
 sed -i "s/memory_limit = 128M/memory_limit = ${PHP_MEM_LIMIT}M/g" /etc/php5/conf.d/php.ini
fi

# Increase the post_max_size
if [ ! -z "$PHP_POST_MAX_SIZE" ]; then
 sed -i "s/post_max_size = 100M/post_max_size = ${PHP_POST_MAX_SIZE}M/g" /etc/php5/conf.d/php.ini
fi

# Increase the upload_max_filesize
if [ ! -z "$PHP_UPLOAD_MAX_FILESIZE" ]; then
 sed -i "s/upload_max_filesize = 100M/upload_max_filesize= ${PHP_UPLOAD_MAX_FILESIZE}M/g" /etc/php5/conf.d/php.ini
fi

# Tweak nginx to match the workers to cpu's
procs=$(cat /proc/cpuinfo |grep processor | wc -l)
sed -i -e "s/worker_processes 5/worker_processes $procs/" /etc/nginx/nginx.conf

# vérification de l'existance d'une branche pour le site
BRANCHE=$(svn info /var/www/html/ | grep URL | head -1 | awk '{ print $2}')
BRANCHE_CIBLE=$(svn info $SVN_REPOSITORY | grep URL | head -1 | awk '{ print $2}')
if [ ! -z $BRANCHE_CIBLE ] && [ $BRANCHE != $BRANCHE_CIBLE ]; then
  echo "Migration vers $DOMAINE_NAME "
  svn switch $SVN_REPOSITORY /var/www/html --quiet
fi

if [ ! -d "/var/www/html/plugins/squelettes" ] ; then
	echo "Installation du squelette"
  svn checkout svn://svn.alg-network.com/dev/interdev/plugins/squelettes/bootskin/branches/$DOMAINE_NAME /var/www/html/plugins/squelettes/$DOMAINE_NAME --quiet
fi

if [ ! -d "/var/www/html/plugins/themes" ] ; then
	echo "Installation du theme"
  svn checkout svn://svn.alg-network.com/dev/design/$DOMAINE_NAME/theme /var/www/html/plugins/themes/$DOMAINE_NAME --quiet
fi

# tweak nginx.conf
sed -i -e "s/localhost/$DOMAINE_NAME/g" /etc/nginx/sites-available/default.conf

# Install website
/install.sh

# Always chown webroot for better mounting
chown -Rf nginx.nginx /var/www/html

#
# Run custom scripts
#if [[ "$RUN_SCRIPTS" == "1" ]] ; then
#  if [ -d "/var/www/html/scripts/" ]; then
#    # make scripts executable incase they aren't
#    chmod -Rf 750 /var/www/html/scripts/*
    # run scripts in number order
#    for i in `ls /var/www/html/scripts/`; do /var/www/html/scripts/$i ; done
#  else
#    echo "Can't find script directory"
#  fi
#fi

# Start supervisord and services
/usr/bin/supervisord -n -c /etc/supervisord.conf

exec "$@"
