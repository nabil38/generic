
sed -i '1,6d' /etc/nginx/sites-available/default.conf
supervisorctl restart nginx
