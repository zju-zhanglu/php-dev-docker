FROM centos:centos7
MAINTAINER pinguoops <pinguo-ops@camera360.com>

# -----------------------------------------------------------------------------
# Make src dir
# -----------------------------------------------------------------------------
ENV HOME /home/worker
ENV SRC_DIR $HOME/src
RUN mkdir -p ${SRC_DIR}

# -----------------------------------------------------------------------------
# Install Development tools
# -----------------------------------------------------------------------------
RUN mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup \
    && wget -q -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo \
    && mv /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.backup \
    && mv /etc/yum.repos.d/epel-testing.repo /etc/yum.repos.d/epel-testing.repo.backup \
    && wget -q -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo \
    && yum makecache \
    && rpm --import /etc/pki/rpm-gpg/RPM* \
    && curl --silent --location https://raw.githubusercontent.com/nodesource/distributions/master/rpm/setup_6.x | bash - \
    && yum -y update \
    && yum groupinstall -y "Development tools" \
    && yum -y install gcc-c++ ncurses-devel sqlite-devel zlib zlib-devel \
    wget man man-pages tar gzip unzip file sudo \
    bzip2 bzip2-devel perl-devel perl-ExtUtils-Embed perl-CPAN \
    pcre pcre-devel openssh-server openssh openssl-devel \
    screen vim git telnet expat expat-devel ca-certificates m4 \
    lemon net-snmp net-snmp-devel net-snmp-libs net-tools \
    gd gd-devel libjpeg libjpeg-devel libpng libpng-devel libevent libevent-devel  \
    freetype freetype-devel libxml2 libxml2-devel unixODBC unixODBC-devel \
    libxslt libxslt-devel libmcrypt libmcrypt-devel freetds freetds-devel \
    libtool-ltdl libtool-ltdl-devel gettext-devel curl-devel \
    openldap openldap-devel libc-client-devel \
    jemalloc jemalloc-devel inotify-tools nodejs apr-util yum-utils tree cronie crontabs python-pip \
    && ln -s /usr/lib64/libc-client.so /usr/lib/libc-client.so \
    && sed -i '/session    required   pam_loginuid.so/c\#session    required   pam_loginuid.so' /etc/pam.d/crond \
    && rm -rf /var/cache/{yum,ldconfig}/* \
    && rm -rf /etc/ld.so.cache \
    && yum clean all

# -----------------------------------------------------------------------------
# Install pip supervisor and distribute ...
# -----------------------------------------------------------------------------
RUN pip install supervisor distribute \
    && rm -rf /tmp/*

# -----------------------------------------------------------------------------
# Configure, timezone/sshd/passwd/networking
# -----------------------------------------------------------------------------
RUN ln -sf /usr/share/zoneinfo/Asia/Chongqing /etc/localtime \
    && sed -i \
        -e 's/^UsePAM yes/#UsePAM yes/g' \
        -e 's/^#UsePAM no/UsePAM no/g' \
        -e 's/#UsePrivilegeSeparation.*/UsePrivilegeSeparation no/g' \
        -e 's/^#UseDNS yes/UseDNS no/g' \
        /etc/ssh/sshd_config \
    && echo "root" | passwd --stdin root \
    && ssh-keygen -q -b 1024 -N '' -t rsa -f /etc/ssh/ssh_host_rsa_key \
    && ssh-keygen -q -b 1024 -N '' -t dsa -f /etc/ssh/ssh_host_dsa_key \
    && echo "NETWORKING=yes" > /etc/sysconfig/network

# -----------------------------------------------------------------------------
# Install curl
# -----------------------------------------------------------------------------
ENV CURL_INSTALL_DIR ${HOME}/libcurl
RUN cd ${SRC_DIR} \
    && wget -q -O curl-7.55.1.tar.gz http://curl.askapache.com/download/curl-7.55.1.tar.gz \
    && tar xzf curl-7.55.1.tar.gz \
    && cd curl-7.55.1 \
    && ./configure --prefix=${CURL_INSTALL_DIR} \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/curl*

# -----------------------------------------------------------------------------
# Install Nginx
# -----------------------------------------------------------------------------
ENV nginx_version 1.12.2
ENV NGINX_INSTALL_DIR ${HOME}/nginx
RUN cd ${SRC_DIR} \
    && wget -q -O nginx-${nginx_version}.tar.gz http://nginx.org/download/nginx-${nginx_version}.tar.gz \
    && wget -q -O nginx-http-concat.zip https://github.com/alibaba/nginx-http-concat/archive/master.zip \
    && wget -q -O nginx-logid.zip https://github.com/pinguo-liuzhaohui/nginx-logid/archive/master.zip \
    && wget -q -O ngx_devel_kit-0.3.0.tar.gz https://github.com/simpl/ngx_devel_kit/archive/v0.3.0.tar.gz \
    && wget -q -O lua-nginx-module-0.10.11.tar.gz https://github.com/openresty/lua-nginx-module/archive/v0.10.11.tar.gz \
    && wget -q -O LuaJIT-2.0.5.tar.gz http://luajit.org/download/LuaJIT-2.0.5.tar.gz \
    && tar zxf nginx-${nginx_version}.tar.gz \
    && unzip nginx-http-concat.zip -d nginx-http-concat \
    && unzip nginx-logid.zip -d nginx-logid \
    && tar zxf ngx_devel_kit-0.3.0.tar.gz \
    && tar zxf lua-nginx-module-0.10.11.tar.gz \
    && tar zxf LuaJIT-2.0.5.tar.gz \
    && cd LuaJIT-2.0.5 \
    && make PREFIX=${HOME}/LuaJIT-2.0.5 1>/dev/null \
    && make install PREFIX=${HOME}/LuaJIT-2.0.5 \
    && cd ${HOME} \
    && ln -s LuaJIT-2.0.5 luajit \
    && export LUAJIT_LIB=${HOME}/luajit/lib \
    && export LUAJIT_INC=${HOME}/luajit/include/luajit-2.0 \
    && cd ${SRC_DIR}/nginx-${nginx_version} \
    && ./configure --prefix=$NGINX_INSTALL_DIR --with-http_stub_status_module --with-http_ssl_module \
        --add-module=../nginx-http-concat/nginx-http-concat-master --add-module=../nginx-logid/nginx-logid-master \
        --with-ld-opt="-Wl,-rpath,${HOME}/luajit/lib" --add-module=../ngx_devel_kit-0.3.0 --add-module=../lua-nginx-module-0.10.11 1>/dev/null \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/nginx-* ${SRC_DIR}/ngx_devel_kit* ${SRC_DIR}/lua-nginx-module* ${SRC_DIR}/LuaJIT*

# -----------------------------------------------------------------------------
# Install Redis
# -----------------------------------------------------------------------------
ENV redis_version 3.2.11
ENV REDIS_INSTALL_DIR ${HOME}/redis
RUN cd ${SRC_DIR} \
    && wget -q -O redis-${redis_version}.tar.gz http://download.redis.io/releases/redis-${redis_version}.tar.gz \
    && tar xzf redis-${redis_version}.tar.gz \
    && cd redis-${redis_version} \
    && make 1>/dev/null \
    && make PREFIX=$REDIS_INSTALL_DIR install \
    && rm -rf ${SRC_DIR}/redis-*

# -----------------------------------------------------------------------------
# Install Mongodb
# -----------------------------------------------------------------------------
ENV mongodb_version 3.4.9
ENV MONGODB_INSTALL_DIR ${HOME}/mongodb/${mongodb_version}
RUN cd ${SRC_DIR} \
    && wget -q -O mongodb-linux-x86_64-rhel62-${mongodb_version}.tgz https://fastdl.mongodb.org/linux/mongodb-linux-x86_64-rhel62-3.4.9.tgz \
    && tar xzf mongodb-linux-x86_64-rhel62-${mongodb_version}.tgz \
    && mkdir -p ${MONGODB_INSTALL_DIR} \
    && mv mongodb-linux-x86_64-rhel62-${mongodb_version}/* ${MONGODB_INSTALL_DIR} \
    && rm -rf ${SRC_DIR}/mongodb*

## -----------------------------------------------------------------------------
## Install Mysql(client)
## -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O mysql57-community-release-el7-11.noarch.rpm https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm \
    && rpm -ivh --nodigest --nosignature mysql57-community-release-el7-11.noarch.rpm \
    && yum -y install mysql-community-client \
    && rm -rf /var/cache/{yum,ldconfig}/* \
    && rm -rf /etc/ld.so.cache \
    && rm -rf ${SRC_DIR}/mysql57-community-release-el7-11.noarch.rpm \
    && yum clean all

# -----------------------------------------------------------------------------
# Install Rabbitmq
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O rabbitmq-c-0.8.0.tar.gz  https://github.com/alanxz/rabbitmq-c/archive/v0.8.0.tar.gz \
    && tar zxf rabbitmq-c-0.8.0.tar.gz \
    && cd rabbitmq-c-0.8.0 \
    && autoreconf -i \
    && ./configure --prefix=${HOME}/rabbitmq-c 1>/dev/null \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/rabbitmq-c*

# -----------------------------------------------------------------------------
# Install otp
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O otp_src_20.0.tar.gz http://erlang.org/download/otp_src_20.0.tar.gz \
    && tar zxf otp_src_20.0.tar.gz \
    && cd otp_src_20.0 \
    && ./configure --enable-hipe --with-ssl \
    && make \
    && make install \
    && rm -rf /var/cache/{yum,ldconfig}/* \
    && rm -rf /etc/ld.so.cache \
    && yum clean all \
    && rm -rf ${SRC_DIR}/otp*

# -----------------------------------------------------------------------------
# Install Rabbitmq server
# -----------------------------------------------------------------------------
ENV RABBIT_INSTALL_DIR $HOME/rabbitmq
RUN cd ${SRC_DIR} \
    && wget -q -O rabbitmq-server-generic-unix-3.6.12.tar.xz http://www.rabbitmq.com/releases/rabbitmq-server/v3.6.12/rabbitmq-server-generic-unix-3.6.12.tar.xz \
    && tar xf rabbitmq-server-generic-unix-3.6.12.tar.xz \
    && mv rabbitmq_server-3.6.12 ${RABBIT_INSTALL_DIR} \
    && rm -rf ${SRC_DIR}/rabbitmq*

# -----------------------------------------------------------------------------
# Install ImageMagick
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O ImageMagick.tar.gz https://www.imagemagick.org/download/ImageMagick.tar.gz \
    && tar zxf ImageMagick.tar.gz \
    && rm -rf ImageMagick.tar.gz \
    && ImageMagickPath=`ls` \
    && cd ${ImageMagickPath} \
    && ./configure \
    && make \
    && make install \
    && rm -rf $SRC_DIR/ImageMagick*

# -----------------------------------------------------------------------------
# Install hiredis
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O hiredis-0.13.3.tar.gz https://github.com/redis/hiredis/archive/v0.13.3.tar.gz \
    && tar zxvf hiredis-0.13.3.tar.gz \
    && cd hiredis-0.13.3 \
    && make \
    && make install \
    && echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf \
    && ldconfig \
    && rm -rf $SRC_DIR/hiredis-*

# -----------------------------------------------------------------------------
# Install libmemcached using by php-memcached
# -----------------------------------------------------------------------------
ENV LIB_MEMCACHED_INSTALL_DIR /usr/local/
RUN cd ${SRC_DIR} \
    && wget -q -O libmemcached-1.0.18.tar.gz https://launchpad.net/libmemcached/1.0/1.0.18/+download/libmemcached-1.0.18.tar.gz \
    && tar xzf libmemcached-1.0.18.tar.gz \
    && cd libmemcached-1.0.18 \
    && ./configure --prefix=$LIB_MEMCACHED_INSTALL_DIR --with-memcached 1>/dev/null \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/libmemcached*

# -----------------------------------------------------------------------------
# Install libmcrypt using by php-mcrypt
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O libmcrypt-2.5.8.tar.gz https://nchc.dl.sourceforge.net/project/mcrypt/Libmcrypt/2.5.8/libmcrypt-2.5.8.tar.gz \
    && tar xzf libmcrypt-2.5.8.tar.gz \
    && cd libmcrypt-2.5.8 \
    && ./configure 1>/dev/null \
    && make 1>/dev/null \
    && make install \
    && echo "/usr/local/lib64" >> /etc/ld.so.conf.d/local.conf \
    && echo "/usr/local/src/libmcrypt-2.5.8/lib/.libs" >> /etc/ld.so.conf.d/local.conf \
    && chmod gu+x /etc/ld.so.conf.d/local.conf \
    && ldconfig -v \
    && rm -rf ${SRC_DIR}/libmcrypt*

# -----------------------------------------------------------------------------
# Install re2c for PHP
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O re2c-1.0.tar.gz https://excellmedia.dl.sourceforge.net/project/re2c/old/re2c-1.0.tar.gz \
    && tar xzf re2c-1.0.tar.gz \
    && cd re2c-1.0 \
    && ./configure \
    && make \
    && make install \
    && rm -rf ${SRC_DIR}/re2c*

# -----------------------------------------------------------------------------
# Install PHP
# -----------------------------------------------------------------------------
ENV phpversion 7.1.9
ENV PHP_INSTALL_DIR ${HOME}/php
RUN cd ${SRC_DIR} \
    && wget -q -O php-${phpversion}.tar.gz http://cn2.php.net/distributions/php-${phpversion}.tar.gz \
    && tar xzf php-${phpversion}.tar.gz \
    && cd php-${phpversion} \
    && ./configure \
       --prefix=${PHP_INSTALL_DIR} \
       --with-config-file-path=${PHP_INSTALL_DIR}/etc \
       --with-config-file-scan-dir=${PHP_INSTALL_DIR}/etc/php.d \
       --sysconfdir=${PHP_INSTALL_DIR}/etc \
       --with-libdir=lib64 \
       --enable-mysqlnd \
       --enable-zip \
       --enable-exif \
       --enable-ftp \
       --enable-mbstring \
       --enable-mbregex \
       --enable-fpm \
       --enable-bcmath \
       --enable-pcntl \
       --enable-soap \
       --enable-sockets \
       --enable-shmop \
       --enable-sysvmsg \
       --enable-sysvsem \
       --enable-sysvshm \
       --enable-gd-native-ttf \
       --enable-wddx \
       --enable-opcache \
       --enable-tokenizer \
       --with-gettext \
       --with-xsl \
       --with-libexpat-dir \
       --with-xmlrpc \
       --with-snmp \
       --with-ldap \
       --enable-mysqlnd \
       --with-mysqli=mysqlnd \
       --with-pdo-mysql=mysqlnd \
       --with-pdo-odbc=unixODBC,/usr \
       --with-gd \
       --with-jpeg-dir \
       --with-png-dir \
       --with-zlib-dir \
       --with-freetype-dir \
       --with-zlib \
       --with-bz2 \
       --with-openssl \
       --with-curl=${CURL_INSTALL_DIR} \
       --with-mcrypt \
       --with-mhash \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${PHP_INSTALL_DIR}/lib/php.ini \
    && cp -f php.ini-development ${PHP_INSTALL_DIR}/lib/php.ini \
    && rm -rf ${SRC_DIR}/php* ${SRC_DIR}/libmcrypt*

# -----------------------------------------------------------------------------
# Install yaml and PHP yaml extension
# -----------------------------------------------------------------------------
RUN cd $SRC_DIR \
    && wget -q -O yaml-0.1.7.tar.gz http://pyyaml.org/download/libyaml/yaml-0.1.7.tar.gz \
    && tar xzf yaml-0.1.7.tar.gz \
    && cd yaml-0.1.7 \
    && ./configure --prefix=/usr/local \
    && make \
    && make install \
    && cd $SRC_DIR \
    && wget -q -O yaml-2.0.2.tgz http://pecl.php.net/get/yaml-2.0.2.tgz \
    && tar xzf yaml-2.0.2.tgz \
    && cd yaml-2.0.2 \
    && $PHP_INSTALL_DIR/bin/phpize \
    && ./configure --with-yaml=/usr/local --with-php-config=$PHP_INSTALL_DIR/bin/php-config \
    && make \
    && make install \
    && rm -rf $SRC_DIR/yaml-*

# -----------------------------------------------------------------------------
# Install PHP mongodb extensions
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O mongodb-1.3.2.tgz http://pecl.php.net/get/mongodb-1.3.2.tgz \
    && tar zxf mongodb-1.3.2.tgz \
    && cd mongodb-1.3.2 \
    && ${PHP_INSTALL_DIR}/bin/phpize \
    && ./configure --with-php-config=$PHP_INSTALL_DIR/bin/php-config 1>/dev/null \
    && make clean \
    && make \
    && make install \
    && rm -rf ${SRC_DIR}/mongodb-*

# -----------------------------------------------------------------------------
# Install PHP amqp extensions
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O amqp-1.9.3.tgz http://pecl.php.net/get/amqp-1.9.3.tgz \
    && tar zxvf amqp-1.9.3.tgz \
    && cd amqp-1.9.3 \
    && ${PHP_INSTALL_DIR}/bin/phpize \
    && ./configure --with-php-config=$PHP_INSTALL_DIR/bin/php-config --with-librabbitmq-dir=${HOME}/rabbitmq-c 1>/dev/null \
    && make clean \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/amqp*

# -----------------------------------------------------------------------------
# Install PHP redis extensions
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O redis-3.1.3.tgz http://pecl.php.net/get/redis-3.1.3.tgz \
    && tar zxf redis-3.1.3.tgz \
    && cd redis-3.1.3 \
    && ${PHP_INSTALL_DIR}/bin/phpize \
    && ./configure --with-php-config=$PHP_INSTALL_DIR/bin/php-config 1>/dev/null \
    && make clean \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/redis-*

# -----------------------------------------------------------------------------
# Install PHP imagick extensions
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O imagick-3.4.3.tgz http://pecl.php.net/get/imagick-3.4.3.tgz \
    && tar zxf imagick-3.4.3.tgz \
    && cd imagick-3.4.3 \
    && ${PHP_INSTALL_DIR}/bin/phpize \
    && ./configure --with-php-config=$PHP_INSTALL_DIR/bin/php-config \
    --with-imagick 1>/dev/null \
    && make clean \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/imagick-*

# -----------------------------------------------------------------------------
# Install PHP xdebug extensions
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O xdebug-2.5.5.tgz http://pecl.php.net/get/xdebug-2.5.5.tgz \
    && tar zxf xdebug-2.5.5.tgz \
    && cd xdebug-2.5.5 \
    && ${PHP_INSTALL_DIR}/bin/phpize \
    && ./configure --with-php-config=$PHP_INSTALL_DIR/bin/php-config 1>/dev/null \
    && make clean \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/xdebug-*

# -----------------------------------------------------------------------------
# Install PHP igbinary extensions
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O igbinary-2.0.1.tgz http://pecl.php.net/get/igbinary-2.0.1.tgz \
    && tar zxf igbinary-2.0.1.tgz \
    && cd igbinary-2.0.1 \
    && ${PHP_INSTALL_DIR}/bin/phpize \
    && ./configure --with-php-config=$PHP_INSTALL_DIR/bin/php-config 1>/dev/null \
    && make clean \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/igbinary-*

# -----------------------------------------------------------------------------
# Install PHP memcached extensions
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O memcached-3.0.3.tgz http://pecl.php.net/get/memcached-3.0.3.tgz \
    && tar xzf memcached-3.0.3.tgz \
    && cd memcached-3.0.3 \
    && ${PHP_INSTALL_DIR}/bin/phpize \
    && ./configure --enable-memcached --with-php-config=$PHP_INSTALL_DIR/bin/php-config \
       --with-libmemcached-dir=$LIB_MEMCACHED_INSTALL_DIR --disable-memcached-sasl 1>/dev/null \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/memcached-*

# -----------------------------------------------------------------------------
# Install PHP yac extensions
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O yac-2.0.2.tgz http://pecl.php.net/get/yac-2.0.2.tgz \
    && tar zxf yac-2.0.2.tgz\
    && cd yac-2.0.2 \
    && ${PHP_INSTALL_DIR}/bin/phpize \
    && ./configure --with-php-config=$PHP_INSTALL_DIR/bin/php-config \
    && make 1>/dev/null \
    && make install \
    && rm -rf $SRC_DIR/yac-*

# -----------------------------------------------------------------------------
# Install PHP swoole extensions
# -----------------------------------------------------------------------------
ENV swooleVersion 1.9.22
RUN cd ${SRC_DIR} \
    && wget -q -O swoole-${swooleVersion}.tar.gz https://github.com/swoole/swoole-src/archive/v${swooleVersion}.tar.gz \
    && tar zxf swoole-${swooleVersion}.tar.gz \
    && cd swoole-src-${swooleVersion}/ \
    && ${PHP_INSTALL_DIR}/bin/phpize \
    && ./configure --with-php-config=$PHP_INSTALL_DIR/bin/php-config --enable-async-redis --enable-openssl \
    && make clean 1>/dev/null \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/swoole*

# -----------------------------------------------------------------------------
# Install PHP inotify extensions
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O inotify-2.0.0.tgz http://pecl.php.net/get/inotify-2.0.0.tgz \
    && tar zxf inotify-2.0.0.tgz \
    && cd inotify-2.0.0 \
    && ${PHP_INSTALL_DIR}/bin/phpize \
    && ./configure --with-php-config=$PHP_INSTALL_DIR/bin/php-config 1>/dev/null \
    && make clean \
    && make 1>/dev/null \
    && make install \
    && rm -rf ${SRC_DIR}/inotify-*

# -----------------------------------------------------------------------------
# Install phpunit
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O phpunit.phar https://phar.phpunit.de/phpunit.phar \
    && mv phpunit.phar ${PHP_INSTALL_DIR}/bin/phpunit \
    && chmod +x ${PHP_INSTALL_DIR}/bin/phpunit

# -----------------------------------------------------------------------------
# Install php composer
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && curl -sS https://getcomposer.org/installer | $PHP_INSTALL_DIR/bin/php \
    && chmod +x composer.phar \
    && mv composer.phar ${PHP_INSTALL_DIR}/bin/composer

# -----------------------------------------------------------------------------
# Install PhpDocumentor
# -----------------------------------------------------------------------------
RUN $PHP_INSTALL_DIR/bin/pear install -a PhpDocumentor

RUN cd ${PHP_INSTALL_DIR} \
    && bin/php bin/composer self-update \
    && bin/pear install PHP_CodeSniffer-2.3.4 \
    && rm -rf /tmp/*

# -----------------------------------------------------------------------------
# Install jq
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O jq-1.5.tar.gz https://github.com/stedolan/jq/archive/jq-1.5.tar.gz \
    && tar zxf jq-1.5.tar.gz \
    && cd jq-jq-1.5 \
    && ./configure --disable-maintainer-mode \
    && make \
    && make install \
    && rm -rf ${SRC_DIR}/jq-*

# -----------------------------------------------------------------------------
# Install Apache ab
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && yum -y remove httpd \
    && mkdir httpd \
    && cd httpd \
    && yumdownloader httpd-tools \
    && rpm2cpio httpd-tools* | cpio -idmv \
    && mkdir -p /home/worker/bin \
    && mv ./usr/bin/ab /home/worker/bin \
    && rm -rf ${SRC_DIR}/httpd

# -----------------------------------------------------------------------------
# Update Git
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && yum -y remove git subversion \
    && wget -q -O git-2.15.1.tar.gz https://github.com/git/git/archive/v2.15.1.tar.gz \
    && tar zxf git-2.15.1.tar.gz \
    && cd git-2.15.1 \
    && make configure \
    && ./configure --without-iconv --prefix=/usr/local/ --with-curl=${CURL_INSTALL_DIR} \
    && make \
    && make install \
    && rm -rf $SRC_DIR/git-2*

# -----------------------------------------------------------------------------
# Install google proto as well to have PHP code generation and PHP extension protobuf
# -----------------------------------------------------------------------------
RUN cd ${SRC_DIR} \
    && wget -q -O protoc-3.5.0-linux-x86_64.zip https://github.com/google/protobuf/releases/download/v3.5.0/protoc-3.5.0-linux-x86_64.zip \
    && unzip protoc-3.5.0-linux-x86_64.zip -d protoc-3.5.0-linux-x86_64 \
    && cd protoc-3.5.0-linux-x86_64 \
    && cp -rf bin/protoc ${HOME}/bin \
    && cp -rf include/google /usr/local/include/ \
    && ${PHP_INSTALL_DIR}/bin/pecl install protobuf-3.5.0.1 \
    && rm -rf ${SRC_DIR}/protoc*

# -----------------------------------------------------------------------------
# Install Node and apidoc and nodemon
# -----------------------------------------------------------------------------
RUN npm install apidoc nodemon -g

RUN ${PHP_INSTALL_DIR}/bin/composer global require "laravel/installer"

# -----------------------------------------------------------------------------
# Copy Config
# -----------------------------------------------------------------------------
ADD run.sh /
ADD config /home/worker/

# -----------------------------------------------------------------------------
# Add user worker
# -----------------------------------------------------------------------------
RUN useradd -M -u 1000 worker \
    && echo "worker" | passwd --stdin worker \
    && echo 'worker  ALL=(ALL)  NOPASSWD: ALL' > /etc/sudoers.d/worker \
    && sed -i \
        -e 's/^#PermitRootLogin yes/PermitRootLogin no/g' \
        -e 's/^PermitRootLogin yes/PermitRootLogin no/g' \
        -e 's/^#PermitUserEnvironment no/PermitUserEnvironment yes/g' \
        -e 's/^PermitUserEnvironment no/PermitUserEnvironment yes/g' \
        /etc/ssh/sshd_config \
    && chmod a+x /run.sh \
    && chmod a+x ${PHP_INSTALL_DIR}/bin/checkstyle \
    && chmod a+x ${PHP_INSTALL_DIR}/bin/mergeCoverReport

# -----------------------------------------------------------------------------
# clean tmp file
# -----------------------------------------------------------------------------
RUN rm -rf ${SRC_DIR}/* /tmp/*

EXPOSE 80 443
ENTRYPOINT ["/run.sh"]
