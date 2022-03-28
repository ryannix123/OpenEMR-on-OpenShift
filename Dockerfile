FROM registry.access.redhat.com/ubi8 as builder
RUN dnf update -y
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
RUN dnf install -y  https://rpms.remirepo.net/enterprise/remi-release-8.rpm
RUN dnf install -y yum-utils
RUN dnf module reset -y php
RUN dnf module install -y php:remi-7.3
RUN dnf install -y @php php-mysqlnd php-soap php-gd php-pecl-zip php-ldap wget git npm
RUN wget https://getcomposer.org/installer -O composer-installer.php
RUN wget https://raw.githubusercontent.com/ryannix123/openemr-php-ini/master/php.ini
RUN wget https://raw.githubusercontent.com/openemr/openemr-devops/master/docker/openemr/5.0.2/autoconfig.sh https://raw.githubusercontent.com/openemr/openemr-devops/master/docker/openemr/6.0.0/auto_configure.php
RUN php composer-installer.php --filename=composer --install-dir=/usr/local/bin

RUN git clone https://github.com/ryannix123/openemr.git --depth 1

WORKDIR openemr
RUN composer install --no-dev
RUN npm install --unsafe-perm \
    && npm run build
RUN composer global require phing/phing \
    && /root/.composer/vendor/bin/phing vendor-clean \
    && /root/.composer/vendor/bin/phing assets-clean \
    && composer global remove phing/phing \
    && composer dump-autoload -o \
    && composer clearcache \
    && npm cache clear --force \
    && rm -fr node_modules
RUN mv sites sites-seed

FROM registry.access.redhat.com/ubi8
RUN dnf install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
RUN dnf install -y  https://rpms.remirepo.net/enterprise/remi-release-8.rpm
RUN dnf install -y yum-utils
RUN dnf module reset -y php
RUN dnf module install -y php:remi-7.3
RUN dnf install -y @php php php-mysqlnd php-soap php-gd httpd mod_ssl openssl && dnf clean all
COPY --from=builder /php.ini /etc/php.ini
COPY --from=builder /openemr /var/www/localhost/htdocs/openemr

COPY openemr.conf /etc/httpd/conf.d/openemr.conf
COPY ssl.conf /etc/httpd/conf.d/ssl.conf
COPY first_start.sh /var/www/localhost/htdocs/openemr/
COPY --from=builder autoconfig.sh auto_configure.php /var/www/localhost/htdocs/openemr/
RUN echo "LoadModule mpm_prefork_module modules/mod_mpm_prefork.so" > /etc/httpd/conf.modules.d/00-mpm.conf

# left-over from upstream, do we really need this?
ENV APACHE_LOG_DIR=/var/log/httpd

RUN chmod 0777 /run/httpd
RUN chmod 0770 /var/log/httpd
RUN chown -R apache /var/www/localhost/htdocs/openemr/
RUN chmod -R 777 /var/lib/php/session

RUN sed -i 's/^Listen 80/Listen 8080/' /etc/httpd/conf/httpd.conf

WORKDIR /var/www/localhost/htdocs/openemr/
CMD exec /usr/sbin/httpd -D FOREGROUND

EXPOSE 8080 8443
