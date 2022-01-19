FROM centos:8.4.2105

WORKDIR /tmp

COPY swoole-src-4.8.3.tar.gz ./
COPY php-8.0.12.tar.gz ./
COPY phpredis-release-5.3.4.zip ./
COPY oniguruma_v6.9.7.1.zip ./
COPY openresty-1.19.9.1.tar.gz ./

RUN yum update -y && yum clean all \
    #安装lnmp依赖 \
    && yum install -y --allowerasing wget make cmake unzip tar gcc gcc-c++ libxml2 libxml2-devel openssl openssl-devel bzip2 bzip2-devel libcurl libcurl-devel libjpeg libjpeg-devel libpng libpng-devel freetype freetype-devel gmp gmp-devel readline readline-devel libxslt libxslt-devel zlib zlib-devel glibc glibc-devel glib2 glib2-devel ncurses curl gdbm-devel libXpm-devel libX11-devel gd-devel gmp-devel expat-devel xmlrpc-c libicu-devel sqlite-devel autoconf automake libtool libzip libzip-devel \
    && unzip oniguruma_v6.9.7.1.zip \
    && cd oniguruma-6.9.7.1 && ./autogen.sh && ./configure --prefix=/usr --libdir=/lib64/ && make && make install \
\
    #安装php
    && cd /tmp \
    && useradd -M www \
    && tar zxvf php-8.0.12.tar.gz \
    && cd php-8.0.12 \
    && ./configure --prefix=/usr/local/webserver/php --with-config-file-path=/usr/local/webserver/php/etc --with-fpm-user=www --with-fpm-group=www --with-curl --with-freetype --enable-gd --with-gettext --with-kerberos --with-libdir=lib64 --with-mysqli --with-openssl --with-external-pcre --with-pdo-mysql --with-pdo-sqlite --with-jpeg --with-xsl --with-zlib --with-bz2 --with-mhash --enable-fpm --enable-bcmath --enable-mbregex --enable-mbstring --enable-opcache --enable-pcntl --enable-shmop --enable-soap --enable-sockets --enable-sysvsem --enable-sysvshm --enable-xml --with-zip \
    && make -j4 && make install \
    && echo "export PATH=$PATH:/usr/local/webserver/php/bin" >> /etc/profile \
    && source /etc/profile \
    && cp php.ini-production /usr/local/webserver/php/etc/php.ini \
    && cd /usr/local/webserver/php/etc \
    && echo "error_log = \/export\/logs\/php\/error\.log" >> php.ini \
    && echo "date\.timezone = UTC" >> php.ini \
    && echo "extension=swoole.so" >> php.ini \
    && echo "extension=redis.so" >> php.ini \
    && echo "swoole.use_shortname=off" >> php.ini \
    && cp php-fpm.conf.default php-fpm.conf \
    && echo "error_log = \/export\/logs\/php\/php-fpm_error.log" >> php-fpm.conf \
    && echo "daemonize = yes" >> php-fpm.conf \
    && echo "rlimit_files = 65535" >> php-fpm.conf \
    && cd php-fpm.d \
    && cp www.conf.default www.conf \
    && sed -i "s/pm\.max_children = 5/pm\.max_children = 200/g" www.conf \
    && echo "access.log = \/export\/logs\/php-fpm_access.log" >> www.conf \
    && echo "slow.log = \/export\/logs\/php-fpm_slow.log" >> www.conf \
    && echo "request_slowlog_timeout = 2" >> www.conf \
\
    #安装openresty \
    && cd /tmp \
    && useradd -M nginx \
    && tar zxvf openresty-1.19.9.1.tar.gz \
    && cd openresty-1.19.9.1 \
    && ./configure --prefix=/usr/local/webserver/openresty --with-luajit --with-http_iconv_module \
    && make -j4 && make install \
    && cd /usr/local/webserver/openresty/nginx/conf \
    && sed -i "s/\#user  nobody;/user  nginx;/g" nginx.conf \
    && sed -i "s/worker_processes  1;/worker_processes  4;/g" nginx.conf \
    && sed -i "s/\#log_format  main  '\$remote_addr \- \$remote_user \[\$time_local\] \"\$request\" '/log_format  main  '\$remote_addr \- \$remote_user \[\$time_local\] \"\$request\" '/g" nginx.conf \
    && sed -i "s/\#                  '\$status \$body_bytes_sent \"\$http_referer\" '/                  '\$status \$body_bytes_sent \"\$http_referer\" '/g" nginx.conf \
    && sed -i "s/\#                  '\"\$http_user_agent\" \"\$http_x_forwarded_for\"';/                  '\"\$http_user_agent\" \"\$http_x_forwarded_for\"';/g" nginx.conf \
    && sed -i "/\#access_log  logs\/access.log  main;/ i\    map \$time_iso8601 \$logdate {\n        '~^(?<ymd>\d{4}-\d{2}-\d{2})' \$ymd;\n        default                       'date-not-found';\n    }\n" nginx.conf \
    && sed -i "s/\#access_log  logs\/access.log  main;/access_log  \/export\/logs\/nginx\/access_\$logdate.log  main;/g" nginx.conf \
    && sed -i "/\#tcp_nopush     on;/ a\    server_tokens   off;" nginx.conf \
    && sed -i "s/\#gzip  on;/gzip  on;/g" nginx.conf \
    && sed -i '$ i\    include vhost/*.conf\n' nginx.conf \
    && ln -s /export/conf/nginx/vhost vhost \
\
    #安装php-redis扩展
    && cd /tmp \
    && unzip phpredis-release-5.3.4.zip \
    && cd phpredis-release-5.3.4 \
    && phpize \
    && ./configure \
    && make -j4 && make install \
\
    #安装swoole扩展
    && cd /tmp \
    && tar zxvf swoole-src-4.8.3.tar.gz \
    && cd swoole-src-4.8.3 \
    && phpize \
    && ./configure --enable-openssl --enable-http2 --enable-swoole-json --enable-swoole-curl \
    && make -j4 && make install \
\
    #删除临时文件
    && cd /tmp \
    && rm -rf phpredis-release-5.3.4 swoole-src-4.8.3 oniguruma-master php-8.0.12.tar.gz phpredis-release-5.3.4.zip swoole-src-4.8.3.tar.gz openresty-1.19.9.1.tar.gz openresty-1.19.9.1 \
\
    #创建工作目录
    && mkdir -p /export/www/dtc_support_web /export/www/dtc_support_app \
\
    #快捷方式
    && echo "export PHP_HOME=/usr/local/webserver/php" >> /etc/profile \
    && echo "export NGINX_HOME=/usr/local/webserver/openresty/nginx" >> /etc/profile \
    && echo "export PATH=$PHP_HOME/bin:$PHP_HOME/sbin:$NGING_HOME/bin:$PATH" >> /etc/profile \
    && source /etc/profile \


WORKDIR /export/www
