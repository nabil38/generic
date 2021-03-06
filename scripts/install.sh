#!/bin/bash

FTP_HOST=${BC_ENV_FTP_HOST}
FTP_PORT=${BC_ENV_FTP_PORT}
FTP_USER=${BC_ENV_FTP_USER}
FTP_PASS=${BC_ENV_FTP_PASS}
FTP_DEV_HOST=${BC_ENV_FTP_DEV_HOST}
FTP_DEV_PORT=${BC_ENV_FTP_DEV_PORT}
FTP_DEV_USER=${BC_ENV_FTP_DEV_USER}
FTP_DEV_PASS=${BC_ENV_FTP_DEV_PASS}
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
  mysql -h$SITE_DATABASE_HOST -u root -p$SITE_DB_ROOT_PASSWORD -e "CREATE DATABASE \`$SITE_DB_NAME\`;"

	if [[ "$SITE_DEPLOYMENT" == "demo" ]] ; then
		echo "Duplicating demo data base"
		mysqldump -uroot -p$SITE_DB_ROOT_PASSWORD -h$SITE_DATABASE_HOST demo | mysql -uroot -p$SITE_DB_ROOT_PASSWORD -h$SITE_DATABASE_HOST $SITE_DB_NAME
	else
	  echo "Looking for database restore"
		if [ -n "${BC_ENV_FTP_DEV_HOST}" ] && [ -n "${BC_ENV_FTP_DEV_USER}" ] && [ -n "${BC_ENV_FTP_DEV_PASS}" ] && [ -n "${BC_ENV_FTP_DEV_PORT}" ] ;then
			if [[ "$SITE_DEPLOYMENT" == "demo" ]] ; then
				echo "    Select demo db for $DOMAINE_NAME"
				BACKUP_MYSQL_FILE="demo.sql.tar.gz"
				MYSQL_FILE_NAME="demo.sql"
			else
				if [[ "$SITE_DEPLOYMENT" == "install" ]] ; then
				echo "    Select install db for $DOMAINE_NAME"
				BACKUP_MYSQL_FILE="install.sql.tar.gz"
				MYSQL_FILE_NAME="install.sql"
				else
					BACKUP_MYSQL_FILE=$(ncftpls -u $BC_ENV_FTP_DEV_USER -p $BC_ENV_FTP_DEV_PASS -P $BC_ENV_FTP_DEV_PORT ftp://$BC_ENV_FTP_DEV_HOST/$BC_ENV_FTP_DIRECTORY/$SITE_DB_NAME.sql.tar.gz)
					MYSQL_FILE_NAME=$SITE_DB_NAME.sql
				fi
			fi
			if [ -z "${BACKUP_MYSQL_FILE}" ] ;then
	      echo "    No database backup found on deploiment ftp server for $DOMAINE_NAME"
				BACKUP_FOLDER=$(ncftpls -x "-lt" -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY | grep backup | head -1 | awk '{print $9}')
			  if [ -n "${BACKUP_FOLDER}" ] ;then
			    BACKUP_MYSQL_FILE=$(ncftpls -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_FOLDER/MYSQL/$SITE_DB_NAME.sql.tar.gz)
			    if [ -z "${BACKUP_MYSQL_FILE}" ] ;then
			      echo "    No database backup found on production backup server for $DOMAINE_NAME in last backup folder ${BACKUP_FOLDER}"
					else
			      echo "    Found latest mysql backup for $DOMAINE_NAME"
			      ncftpget -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_FOLDER/MYSQL/$BACKUP_MYSQL_FILE
			      tar -xvzf $BACKUP_MYSQL_FILE
			      BACKUP_MYSQL_FILE=$SITE_DB_NAME.sql
			    fi
				fi
	    else
	      echo "    Found deploiment mysql backup for $DOMAINE_NAME"
	      ncftpget -u $BC_ENV_FTP_DEV_USER -p $BC_ENV_FTP_DEV_PASS -P $BC_ENV_FTP_DEV_PORT ftp://$BC_ENV_FTP_DEV_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_MYSQL_FILE
	      tar -xvzf $BACKUP_MYSQL_FILE
	    fi
		fi
	  if [ -z "${BACKUP_MYSQL_FILE}" ]; then
	    echo "No database backup found"
	  else
			if [[ "$SITE_DEPLOYMENT" == "install" ]] ; then
				sed -i -e "s/demo2.gd-obs.com/$DOMAINE_NAME/g" $MYSQL_FILE_NAME
			fi
	    echo "Recuperation de la base ${MYSQL_FILE_NAME}"
	    mysql -u root -p$SITE_DB_ROOT_PASSWORD -h$SITE_DATABASE_HOST $SITE_DB_NAME < $MYSQL_FILE_NAME
	    rm -rf $MYSQL_FILE_NAME $MYSQL_FILE_NAME.tar.gz
	  fi
	fi
fi
# check if MYSQL is correctly configured
MYSQL_GLOBAL="$(mysql -h$SITE_DATABASE_HOST -uroot -p$SITE_DB_ROOT_PASSWORD -se "SELECT @@GLOBAL.sql_mode global")"
if [[ "$MYSQL_GLOBAL" != "" ]] ; then
	  mysql -h$SITE_DATABASE_HOST -uroot -p$SITE_DB_ROOT_PASSWORD -e "SET GLOBAL sql_mode = '';"
fi
# Check if user exist
RESULT_USER="$(mysql -h$SITE_DATABASE_HOST -uroot -p$SITE_DB_ROOT_PASSWORD -se "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$SITE_DB_NAME')")"
# Configuring database credentials
if [[ "$RESULT_USER" == "0" ]] ; then
    mysql -h$SITE_DATABASE_HOST -uroot -p$SITE_DB_ROOT_PASSWORD -e "CREATE USER '$SITE_DB_NAME'@'%' IDENTIFIED BY '$SITE_DB_PASSWORD';"
    mysql -h$SITE_DATABASE_HOST -uroot -p$SITE_DB_ROOT_PASSWORD -e "GRANT ALL PRIVILEGES ON \`$SITE_DB_NAME\`.* TO '$SITE_DB_NAME'@'%';"
    mysql -h$SITE_DATABASE_HOST -uroot -p$SITE_DB_ROOT_PASSWORD -e "FLUSH PRIVILEGES;"
fi

# restoring spip configration
if [ ! -f "/var/www/html/config/mes_options.php" ] ; then
  echo "mise à jour de la timezone"
  sed -i -e "s/TIME_ZONE/$TIME_ZONE/g" /root/config_spip/mes_options.php
	sed -i "16i define('_SYSTEM_TYPE','$SYSTEM_TYPE');" /root/config_spip/mes_options.php
fi
if [ ! -f "/var/www/html/config/connect.php" ] ; then
  echo "mise à jour du fichier de connexion"
  sed -i -e "s/MYSQL_ADRESSE/$SITE_DATABASE_HOST/g" /root/config_spip/connect.php
  sed -i -e "s/MYSQL_USER/$SITE_DB_NAME/g" /root/config_spip/connect.php
  sed -i -e "s/MYSQL_PASSWORD/$SITE_DB_PASSWORD/g" /root/config_spip/connect.php
  sed -i -e "s/MYSQL_BASE/$SITE_DB_NAME/g" /root/config_spip/connect.php
	mv /root/config_spip/* /var/www/html/config/.
fi
rm -rf /root/config_spip
if [ -d "/var/www/html/client" ] ; then
	# rstoring thelia configration
	if [ -f "/var/www/html/client/config_thelia.php" ] ; then
	  echo "mise à jour du fichier de connexion thelia"
	  sed -i -e "s/votre_serveur/$SITE_DATABASE_HOST/g" /var/www/html/client/config_thelia.php
	  sed -i -e "s/votre_login_mysql/$SITE_DB_NAME/g" /var/www/html/client/config_thelia.php
	  sed -i -e "s/votre_motdepasse_mysql/$SITE_DB_PASSWORD/g" /var/www/html/client/config_thelia.php
	  sed -i -e "s/bdd_sql/$SITE_DB_NAME/g" /var/www/html/client/config_thelia.php
	fi
	if [ -f "/var/www/html/classes/Cnx.class.php.orig" ] ; then
		mv /var/www/html/classes/Cnx.class.php.orig /var/www/html/classes/Cnx.class.php
	fi

	# Restoring thelia config files
	echo "!!!!!!!!!May need to restore thelia config files"

	# Restoring FILES
	if [ ! -f "/var/www/html/client/plugins/thelia_conf_ok.txt" ];then
	  echo "Looking for Thelia config Files to restore"
		touch /var/www/html/client/plugins/thelia_conf_ok.txt
		# recuperation de la sauvegarde pour le deploiement
		if [ -n "${BC_ENV_FTP_DEV_HOST}" ] && [ -n "${BC_ENV_FTP_DEV_USER}" ] && [ -n "${BC_ENV_FTP_DEV_PASS}" ] && [ -n "${BC_ENV_FTP_DEV_PORT}" ] ;then
			BACKUP_CNF_FILE=$(ncftpls -u $BC_ENV_FTP_DEV_USER -p $BC_ENV_FTP_DEV_PASS -P $BC_ENV_FTP_DEV_PORT ftp://$BC_ENV_FTP_DEV_HOST/$BC_ENV_FTP_DIRECTORY/"$DATA_VOLUME"_thelia_conf.tar.gz)
			if [ -z "${BACKUP_CNF_FILE}" ] ;then
				echo "    No thelia config backup (/$BC_ENV_FTP_DIRECTORY/$DATA_VOLUME_thelia_conf.tar.gz) found for $DOMAINE_NAME in deploiment ftp server"
			  BACKUP_FOLDER=$(ncftpls -x "-lt" -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY | grep backup | head -1 | awk '{print $9}')
			  if [ -n "${BACKUP_FOLDER}" ] ;then
			    BACKUP_CNF_FILE=$(ncftpls -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_FOLDER/FILES/"$DATA_VOLUME"_thelia_conf.tar.gz)
			    if [ -z "${BACKUP_CNF_FILE}" ] ;then
			      echo "    No thelia config backup found on production backup server for $DOMAINE_NAME in last backup folder ${BACKUP_FOLDER}"
			    else
			      echo "    Found latest thelia config backup for $DOMAINE_NAME"
			      ncftpget -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_FOLDER/FILES/$BACKUP_CNF_FILE
			      tar -xvzf $BACKUP_CNF_FILE
			    fi
			  fi
			else
				echo "    Found deploiment thelia config backup for $DOMAINE_NAME"
				ncftpget -u $BC_ENV_FTP_DEV_USER -p $BC_ENV_FTP_DEV_PASS -P $BC_ENV_FTP_DEV_PORT ftp://$BC_ENV_FTP_DEV_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_CNF_FILE
				tar -xvzf $BACKUP_CNF_FILE
			fi
		fi
	  if [ -z "${BACKUP_CNF_FILE}" ]; then
	    echo "No thelia config backup found"
	#    mv /root/config_spip/mes_options.php /var/www/html/config/.
	  else
	    echo "Recuperation de la sauvegarde thelia config pour $DOMAINE_NAME"
	    if [ -d thelia_conf ]; then
				mv thelia_conf/atos/conf/* /var/www/html/client/plugins/atos/conf/.
				mv thelia_conf/atos/config.php /var/www/html/client/plugins/atos/.
				mv thelia_conf/vads/config.php /var/www/html/client/plugins/vads/.
	    	rm -rf thelia_conf $BACKUP_CNF_FILE
				if [ ! -f "/var/www/html/client/plugins/atos/conf/pathfile" ] ; then
				  sed -i -e "s/$DOMAINE_NAME/html/g" /var/www/html/client/plugins/atos/conf/pathfile
				fi
			else
				echo "impossible de restaurer les fichiers de config thelia, verfier le nom du repertoire de sauvegarde"
			fi
	  fi
	fi
fi

# Restoring FILES
if [ $(ls /var/www/html/IMG | wc -l) -lt 1 ];then
  echo "Looking for Files to restore"
	# recuperation de la sauvegarde pour le deploiement
	if [ -n "${BC_ENV_FTP_DEV_HOST}" ] && [ -n "${BC_ENV_FTP_DEV_USER}" ] && [ -n "${BC_ENV_FTP_DEV_PASS}" ] && [ -n "${BC_ENV_FTP_DEV_PORT}" ] ;then
		BACKUP_IMG_FILE=$(ncftpls -u $BC_ENV_FTP_DEV_USER -p $BC_ENV_FTP_DEV_PASS -P $BC_ENV_FTP_DEV_PORT ftp://$BC_ENV_FTP_DEV_HOST/$BC_ENV_FTP_DIRECTORY/"$DATA_VOLUME"_IMG.tar.gz)
		if [ -z "${BACKUP_IMG_FILE}" ] ;then
			echo "    No IMG backup (/$BC_ENV_FTP_DIRECTORY/$DATA_VOLUME.tar.gz) found for $DOMAINE_NAME in deploiment ftp server"
		  BACKUP_FOLDER=$(ncftpls -x "-lt" -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY | grep backup | head -1 | awk '{print $9}')
		  if [ -n "${BACKUP_FOLDER}" ] ;then
		    BACKUP_IMG_FILE=$(ncftpls -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_FOLDER/FILES/"$DATA_VOLUME"_IMG.tar.gz)
		    if [ -z "${BACKUP_IMG_FILE}" ] ;then
		      echo "    No IMG backup found on production backup server for $DOMAINE_NAME in last backup folder ${BACKUP_FOLDER}"
		    else
		      echo "    Found latest IMG backup for $DOMAINE_NAME"
		      ncftpget -u $BC_ENV_FTP_USER -p $BC_ENV_FTP_PASS -P $BC_ENV_FTP_PORT ftp://$BC_ENV_FTP_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_FOLDER/FILES/$BACKUP_IMG_FILE
		      tar -xvzf $BACKUP_IMG_FILE
		    fi
		  fi
		else
			echo "    Found deploiment IMG backup for $DOMAINE_NAME"
			ncftpget -u $BC_ENV_FTP_DEV_USER -p $BC_ENV_FTP_DEV_PASS -P $BC_ENV_FTP_DEV_PORT ftp://$BC_ENV_FTP_DEV_HOST/$BC_ENV_FTP_DIRECTORY/$BACKUP_IMG_FILE
			tar -xvzf $BACKUP_IMG_FILE
		fi
	fi
  if [ -z "${BACKUP_IMG_FILE}" ]; then
    echo "No IMG backup found"
#    mv /root/config_spip/mes_options.php /var/www/html/config/.
  else
    echo "Recuperation de la sauvegarde IMG pour $DOMAINE_NAME"
    if [ -d IMG ]; then
			mv IMG/* /var/www/html/IMG/.
    	rm -rf IMG $BACKUP_IMG_FILE
		elif [ -d "$DATA_VOLUME"_IMG ]; then
			mv "$DATA_VOLUME"_IMG/* /var/www/html/IMG/.
    	rm -rf "$DATA_VOLUME"_IMG $BACKUP_IMG_FILE
		else
			echo "impossible de restaurer les images verfier le nom du repertoire de sauvegarde"
		fi
  fi
fi

# workaround récupération geo dans evts
sed -i '/departement/d' /var/www/html/plugins/gis/saisies/carte.html
sed -i '/country_code/d' /var/www/html/plugins/gis/saisies/carte.html

# netpyage périodique du cache javascript pour éviter l'explosion et le blocage en attendant de traiter la source
# nétoyage du cache js une fois par semaine
sed -i "\$i 0       3       *       *       1       rm -rf /var/www/html/local/cache-js" /etc/crontabs/root
# demarage de crond si pas déjà démarré
if [ $(ps -ef | grep -v grep | grep crond | wc -l) -eq 0 ]; then crond; fi
