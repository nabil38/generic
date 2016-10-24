#!/bin/bash

FTP_HOST=${BC_ENV_FTP_HOST}
FTP_PORT=${BC_ENV_FTP_PORT}
FTP_USER=${BC_ENV_FTP_USER}
FTP_PASS=${BC_ENV_FTP_PASS}
FTP_DIRECTORY=${BC_ENV_FTP_DIRECTORY}

[ -z "${BC_ENV_FTP_HOST}" ] && { echo "=> BC_ENV_FTP_HOST cannot be empty, link to backup service first" && exit 1; }
[ -z "${BC_ENV_FTP_PORT}" ] && { echo "=> BC_ENV_FTP_PORT cannot be empty, link to backup service first" && exit 1; }
[ -z "${BC_ENV_FTP_USER}" ] && { echo "=> BC_ENV_FTP_USER cannot be empty, link to backup service first" && exit 1; }
[ -z "${BC_ENV_FTP_PASS}" ] && { echo "=> BC_ENV_FTP_PASS cannot be empty, link to backup service first" && exit 1; }
[ -z "${BC_ENV_FTP_DIRECTORY}" ] && { echo "=> BC_ENV_FTP_DIRECTORY cannot be empty, link to backup service first" && exit 1; }

# Database setup
: "${SITE_DATABASE_HOST:=mysql}"

# Check if database exist
{
	RESULT=$(mysql -uroot -p$SITE_DB_ROOT_PASSWORD -h$SITE_DATABASE_HOST -e "SHOW DATABASES" | grep -Fo $SITE_DB_NAME)
} || {
	RESULT="0"
}

# restoring database
if [[ "$RESULT" == "0" ]] ; then
  echo "Creating new empty database $SITE_DB_NAME"
  mysql -h$SITE_DATABASE_HOST -u root -p$SITE_DB_ROOT_PASSWORD -e "CREATE DATABASE $SITE_DB_NAME;"

  echo "Looking for database restore"
  BACKUP_FOLDER=$(ncftpls -x "-lt" -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY | grep backup | head -1 | awk '{print $9}')
  if [ -n "${BACKUP_FOLDER}" ] ;then
    BACKUP_MYSQL_FILE=$(ncftpls -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_FOLDER/MYSQL/$SITE_DB_NAME.sql.tar.gz)
    if [ -z "${BACKUP_MYSQL_FILE}" ] ;then
      echo "    No database backup found for $DOMAINE_NAME in last backup folder ${BACKUP_FOLDER}"
    else
      echo "    Found latest mysql backup for $DOMAINE_NAME"
      ncftpget -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_FOLDER/MYSQL/$BACKUP_MYSQL_FILE
      tar -xvzf $BACKUP_MYSQL_FILE
      BACKUP_MYSQL_FILE=$SITE_DB_NAME.sql
    fi
  fi
  if [ -z "${BACKUP_MYSQL_FILE}" ]; then
    echo "No database backup found"
    mv /root/config_spip/mes_options.php /var/www/html/config/.
  else
    echo "Recuperation de la base ${BACKUP_MYSQL_FILE}"
    mysql -u root -p$SITE_DB_ROOT_PASSWORD -h$SITE_DATABASE_HOST $SITE_DB_NAME < $BACKUP_MYSQL_FILE
    rm -rf $BACKUP_MYSQL_FILE $BACKUP_MYSQL_FILE.tar.gz
  fi
fi

# Check if user exist
RESULT_USER="$(mysql -h$SITE_DATABASE_HOST -uroot -p$SITE_DB_ROOT_PASSWORD -se "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$SITE_DB_NAME')")"
# Configuring database credentials
if [[ "$RESULT_USER" == "0" ]] ; then
    mysql -h$SITE_DATABASE_HOST -uroot -p$SITE_DB_ROOT_PASSWORD -e "CREATE USER '$SITE_DB_NAME'@'%' IDENTIFIED BY '$SITE_DB_PASSWORD';"
    mysql -h$SITE_DATABASE_HOST -uroot -p$SITE_DB_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON $SITE_DB_NAME.* TO '$SITE_DB_NAME'@'%';"
    mysql -h$SITE_DATABASE_HOST -uroot -p$SITE_DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
fi

# rstoring configration
if [ ! -f "/var/www/html/config/connect.php" ] ; then
  echo "mise à jour du fichier de connexion"
  sed -i -e "s/MYSQL_ADRESSE/$SITE_DATABASE_HOST/g" /root/config_spip/connect.php
  sed -i -e "s/MYSQL_USER/$SITE_DB_NAME/g" /root/config_spip/connect.php
  sed -i -e "s/MYSQL_PASSWORD/$SITE_DB_PASSWORD/g" /root/config_spip/connect.php
  sed -i -e "s/MYSQL_BASE/$SITE_DB_NAME/g" /root/config_spip/connect.php
  mv /root/config_spip/* /var/www/html/config/.
fi
rm -rf /root/config_spip

# Restoring FILES
if [ $(ls /var/www/html/IMG | wc -l) -lt 1 ];then
  echo "Looking for Files restore"
  BACKUP_FOLDER=$(ncftpls -x "-lt" -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY | grep backup | head -1 | awk '{print $9}')
  if [ -n "${BACKUP_FOLDER}" ] ;then
    BACKUP_IMG_FILE=$(ncftpls -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_FOLDER/FILES/"$DATA_VOLUME"_IMG.tar.gz)
    if [ -z "${BACKUP_IMG_FILE}" ] ;then
      echo "    No IMG backup found for $DOMAINE_NAME in last backup folder ${BACKUP_FOLDER}"
    else
      echo "    Found latest IMG backup for $DOMAINE_NAME"
      ncftpget -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_FOLDER/FILES/$BACKUP_IMG_FILE
      tar -xvzf $BACKUP_IMG_FILE
    fi
  fi
  if [ -z "${BACKUP_IMG_FILE}" ]; then
    echo "No IMG backup found"
#    mv /root/config_spip/mes_options.php /var/www/html/config/.
  else
    echo "Recuperation de la sauvegarde IMG pour $DOMAINE_NAME"
    mv IMG/* /var/www/html/IMG/.
    rm -rf IMG $BACKUP_IMG_FILE
  fi
fi
