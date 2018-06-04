
sed -i '1,6d' /etc/nginx/sites-available/default.conf
sed -i -e "s/www.$DOMAINE_NAME/$SITE_DB_NAME.gd-obs.com/g" /etc/nginx/sites-available/default.conf
supervisorctl restart nginx
