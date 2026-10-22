FROM ubuntu:26.04

LABEL maintainer="Seppe vanden Broucke <seppe.vandenbroucke@kuleuven.be>"

ENV DEBIAN_FRONTEND=noninteractive

# Apache + PHP 8.5 + MySQL 8.4 + Java 8 (the bundled HBase 1.3.1 and
# cyphershell.jar expect Java 8).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apache2 libapache2-mod-php php php-mysql \
        mysql-server openjdk-8-jre-headless \
        ca-certificates curl gnupg dos2unix \
    && rm -rf /var/lib/apt/lists/*

# MongoDB 8.2. The 8.0 line refuses to start on Linux kernels >= 6.19
# (MongoDB SERVER-121912), which affects current Docker hosts. The 8.2 repo is
# signed with the same key as 8.0 (the server-8.2.asc file does not exist).
# MongoDB has no 26.04 (resolute) repository yet; the noble packages work on
# 26.04 and are the newest published 8.2 build.
RUN curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
        | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.2.gpg \
    && echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-8.2.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/8.2 multiverse" \
        > /etc/apt/sources.list.d/mongodb-org-8.2.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends mongodb-org-server mongodb-mongosh \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /data/db

# mongosh writes its state under $HOME (/var/www for www-data).
RUN mkdir -p /var/www/.mongodb && chown www-data:www-data /var/www/.mongodb

RUN { \
        echo '<Directory /var/www/html/>'; \
        echo '  AllowOverride All'; \
        echo '</Directory>'; \
    } > /etc/apache2/conf-available/docker-php.conf \
    && a2enmod rewrite \
    && a2enconf docker-php

ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# The tarball has STANDALONE=true and container-local credentials
# (MySQL root/root, MongoDB admin/playground).
#
# Docker caches this layer by instruction text, not by remote content. After
# regenerating the tarball, rebuild with --no-cache or bump TARBALL_REV.
ARG TARBALL_REV=caea89b3
RUN echo "site tarball revision: ${TARBALL_REV}" \
    && curl -fsSL --retry 3 -o /pdbmbook.tar \
        https://www.pdbmbook.com/static/pdbmbook-docker.tar \
    && tar -xf /pdbmbook.tar -C /var/www/html \
    && rm /pdbmbook.tar \
    && rm -f /var/www/html/index.html \
    && mkdir -p /var/www/html/lib/hbase-1.3.1/logs \
    && chmod 0777 /var/www/html/lib/hbase-1.3.1/logs

ENV JAVA_HOME=/usr

EXPOSE 80

CMD ["/entrypoint.sh"]
