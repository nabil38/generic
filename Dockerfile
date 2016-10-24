FROM alpine:3.4

MAINTAINER Nabil Djidi <public@djidi.com>

ENV php_conf /etc/php5/php.ini
ENV fpm_conf /etc/php5/php-fpm.conf

    RUN apk update && \
        apk add --no-cache bash \
        openssh-client \
        wget \
        nginx \
        supervisor \
        curl \
        git \
        subversion \
        cyrus-sasl \
        cyrus-sasl-digestmd5 \
        php5-fpm \
        php5-pdo \
        php5-pdo_mysql \
        php5-mysql \
        php5-mysqli \
        php5-mcrypt \
        php5-ctype \
        php5-zlib \
        php5-gd \
        php5-intl \
        php5-sqlite3 \
        php5-pgsql \
        php5-xml \
        php5-xsl \
        php5-curl \
        php5-openssl \
        php5-iconv \
        php5-json \
        php5-phar \
        php5-soap \
        php5-dom \
        mysql-client \
        ncftp \
        php5-zip &&\
        mkdir -p /etc/nginx && \
        mkdir -p /var//app && \
        mkdir -p /run/nginx && \
        mkdir -p /var/log/supervisor

RUN apk --no-cache add ca-certificates && \
wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://raw.githubusercontent.com/sgerrand/alpine-pkg-php5-memcached/master/sgerrand.rsa.pub && \
wget https://github.com/sgerrand/alpine-pkg-php5-memcached/releases/download/2.2.0-r0/php5-memcached-2.2.0-r0.apk && \
apk add php5-memcached-2.2.0-r0.apk && \
rm php5-memcached-2.2.0-r0.apk

# Copy our nginx config
RUN rm -Rf /etc/nginx/nginx.conf
ADD conf/nginx.conf /etc/nginx/nginx.conf

# tweak php-fpm config
RUN sed -i -e "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g" ${php_conf} && \
sed -i -e "s/upload_max_filesize\s*=\s*2M/upload_max_filesize = 100M/g" ${php_conf} && \
sed -i -e "s/post_max_size\s*=\s*8M/post_max_size = 100M/g" ${php_conf} && \
sed -i -e "s/session.save_handler = files/session.save_handler = memcache/g" ${php_conf} && \
sed -i -e 's#;session.save_path = "/var/lib/php5"#session.save_path = "mcserver"#g' /${php_conf} && \
sed -i -e "s/variables_order = \"GPCS\"/variables_order = \"EGPCS\"/g" ${php_conf} && \
sed -i -e "s/;daemonize\s*=\s*yes/daemonize = no/g" ${fpm_conf} && \
sed -i -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" ${fpm_conf} && \
sed -i -e "s/pm.max_children = 4/pm.max_children = 4/g" ${fpm_conf} && \
sed -i -e "s/pm.start_servers = 2/pm.start_servers = 3/g" ${fpm_conf} && \
sed -i -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 2/g" ${fpm_conf} && \
sed -i -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 4/g" ${fpm_conf} && \
sed -i -e "s/pm.max_requests = 500/pm.max_requests = 200/g" ${fpm_conf} && \
sed -i -e "s/user = nobody/user = nginx/g" ${fpm_conf} && \
sed -i -e "s/group = nobody/group = nginx/g" ${fpm_conf} && \
sed -i -e "s/;listen.mode = 0660/listen.mode = 0666/g" ${fpm_conf} && \
sed -i -e "s/;listen.owner = nobody/listen.owner = nginx/g" ${fpm_conf} && \
sed -i -e "s/;listen.group = nobody/listen.group = nginx/g" ${fpm_conf} && \
sed -i -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" ${fpm_conf} &&\
sed -i -e "s/^;clear_env = no$/clear_env = no/" ${fpm_conf} &&\
ln -s /etc/php5/php.ini /etc/php5/conf.d/php.ini && \
find /etc/php5/conf.d/ -name "*.ini" -exec sed -i -re 's/^(\s*)#(.*)/\1;\2/g' {} \;

# nginx site conf
RUN rm -Rf /etc/nginx/conf.d/* && \
mkdir -p /etc/nginx/sites-available/ && \
mkdir -p /etc/nginx/sites-enabled/ && \
mkdir -p /etc/nginx/ssl/ && \
rm -Rf /var/www/*
ADD conf/nginx-site.conf /etc/nginx/sites-available/default.conf
ADD conf/nginx-site-ssl.conf /etc/nginx/sites-available/default-ssl.conf
RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

# Supervisor Config
ADD conf/supervisord.conf /etc/supervisord.conf

# Add Scripts
ADD scripts/start.sh /start.sh
ADD scripts/install.sh /install.sh
ADD scripts/pull /usr/bin/pull
ADD scripts/push /usr/bin/push
ADD secret/servers /root/.subversion/servers
ADD docs/config_spip /root/config_spip
RUN chmod 755 /usr/bin/pull && chmod 755 /usr/bin/push && chmod 755 /start.sh && chmod 755 /install.sh

ARG svn_user
ARG svn_pass
ARG svn_repo="svn://svn.alg-network.com/dev/interdev/spip/tags/generic"

# copy in code
RUN svn checkout --force --username $svn_user --password="$svn_pass" $svn_repo /var/www/html
ADD src/infos.php /var/www/html/infos.php

#VOLUME /var/www/html

EXPOSE 443 80

#CMD ["/usr/bin/supervisord", "-n", "-c",  "/etc/supervisord.conf"]
CMD ["/bin/bash", "/start.sh"]
