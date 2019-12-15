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
  svn switch --ignore-ancestry $SVN_REPOSITORY /var/www/html --quiet
else
  echo "Mise à jour de $DOMAINE_NAME "
  svn update /var/www/html --quiet
fi

echo "modification des compatbilités plugins pour fonctionner sur spip 3.2 (à supprimer une fois plus necessaire)"
sed -i -e "s/3.1./3.2./g" /var/www/html/plugins/bootstrap/paquet.xml
sed -i -e "s/3.1./3.2./g" /var/www/html/plugins/ckeditor-spip-plugin/paquet.xml
if [ -f "/var/www/html/plugins/gis/saisies/carte.html"] ; then
  sed -i "/departement/d" /var/www/html/plugins/gis/saisies/carte.html
  sed -i "/country_code/d" /var/www/html/plugins/gis/saisies/carte.html
fi
if [ -z $DESIGN ] ; then DESIGN=$DOMAINE_NAME ; fi
if [ ! -d "/var/www/html/plugins/squelettes" ] ; then
	echo "Installation du squelette"
  svn checkout svn://svn.alg-network.com/dev/interdev/plugins/squelettes/bootskin/branches/$DESIGN /var/www/html/plugins/squelettes/$DESIGN --quiet
fi

if [ ! -d "/var/www/html/plugins/themes" ] ; then
	echo "Installation du theme"
  svn checkout svn://svn.alg-network.com/dev/design/$DESIGN/theme /var/www/html/plugins/themes/$DESIGN --quiet
fi

# tweak nginx.conf
sed -i -e "s/localhost/$DOMAINE_NAME/g" /etc/nginx/sites-available/default.conf
[[ "$DOMAINE_NAME" =~ ".gd-obs.com"$ ]] && sed -i '1,6d' /etc/nginx/sites-available/default.conf

# Install website
echo "Installation Site"
/install.sh

# Always chown webroot for better mounting
echo "changement droits"
chown -Rf nginx.nginx /var/www/html/IMG
chown -Rf nginx.nginx /var/www/html/tmp
chown -Rf nginx.nginx /var/www/html/local
chown -Rf nginx.nginx /var/www/html/client/cache
chown -Rf nginx.nginx /var/www/html/plugins/expocompta/export
chown -Rf nginx.nginx /var/www/html/plugins/themes

#
# Run custom scripts
#if [[ "$RUN_SCRIPTS" == "1" ]] ; then
#  if [ -d "/var/www/html/scripts/" ]; then
#    # make scripts executable incase they aren't
#    chmod -Rf 750 /var/www/html/scripts/*
#    # run scripts in number order
#    for i in `ls /var/www/html/scripts/`; do /var/www/html/scripts/$i ; done
#  else
#    echo "Can't find script directory"
#  fi
#fi

# Start supervisord and services
echo "demarrage des services"
/usr/bin/supervisord -n -c /etc/supervisord.conf

exec "$@"
