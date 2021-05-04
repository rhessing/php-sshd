FROM php:8-cli-buster
MAINTAINER R. Hessing

# Set default timezone to UTC
ENV TZ=Etc/UTC
ENV TINI_VERSION v0.19.0

# Install requirements for Tini and PHP extension builds
RUN apt-get update && apt-get install --no-install-recommends -y \
        default-mysql-client \
        dirmngr \
        git \
        libaspell-dev \
        libicu-dev \
        libmcrypt-dev \
        libunistring-dev \
        libuv1-dev \
        libzip-dev \
        libmagickwand-dev \
        libmemcached-dev \
        libtidy-dev \
        openssh-server \
        unzip \
        zip \
        zlib1g-dev

# Install tiny
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /bin/tini
COPY docker-entrypoint.sh /usr/local/bin/

# Install composer
# Create default user 'php'
# Fix issue with k8s authorized_keys and configmaps
RUN chmod 755 /bin/tini \
    && chmod 755 /usr/local/bin/docker-entrypoint.sh \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && mkdir -p /var/www \
    && addgroup -gid 1000 php \
    && adduser -uid 1000 -gid 1000 --shell /bin/bash --disabled-password --gecos '' php \
    && passwd -u php \
    && mkdir -p /home/php/.ssh \
    && chown php:php /home/php/.ssh \
    && chmod 0700 /home/php/.ssh

# Configure, build and install additional PHP extensions
RUN docker-php-ext-configure pdo_mysql \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-enable pdo_mysql \
    && docker-php-ext-configure mysqli \
    && docker-php-ext-install -j$(nproc) mysqli \
    && docker-php-ext-enable mysqli \
    && docker-php-ext-configure shmop \
    && docker-php-ext-install -j$(nproc) shmop \
    && docker-php-ext-enable shmop \
    && docker-php-ext-configure tidy \
    && docker-php-ext-install -j$(nproc) tidy \
    && docker-php-ext-enable tidy \
    && docker-php-ext-configure zip \
    && docker-php-ext-install -j$(nproc) zip \
    && docker-php-ext-enable zip \
    && pecl channel-update pecl.php.net \
    && pecl install mcrypt \
    && pecl install memcached \
    && pecl install redis \
    && pecl install xdebug \
    && docker-php-ext-enable mcrypt \
    && docker-php-ext-enable memcached \
    && docker-php-ext-enable redis \
    && docker-php-ext-enable xdebug \
    && rm -rf /tmp/* \
    && rm -rf /var/cache/apt/* \
    # Always refresh keys
    && rm -rf /etc/ssh/ssh_host_rsa_key /etc/ssh/ssh_host_dsa_key

# Configure PHP
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && printf '[PHP]\ndate.timezone = "__TIMEZONE__"\n' > /usr/local/etc/php/conf.d/tzone.ini \
    && echo "zend_extension = $(find /usr/local/lib/php/extensions/ -name xdebug.so)" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "error_reporting = __ERROR_REPORTING__" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "display_startup_errors = __DISPLAY_STARTUP_ERRORS__" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "display_errors = __DISPLAY_ERRORS__" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.file_link_format = __FILE_LINK_FORMAT__" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.idekey = \"__IDEKEY__\"" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.remote_port = __REMOTE_PORT__" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.remote_enable = __REMOTE_ENABLE__" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.remote_autostart = __REMOTE_AUTOSTART__" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.remote_host = __REMOTE_HOST__" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

EXPOSE 22
ENTRYPOINT ["/bin/tini", "--"]

CMD ["/usr/local/bin/docker-entrypoint.sh"]
