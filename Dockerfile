FROM ubuntu:xenial
MAINTAINER Seppe vanden Broucke <seppe.vandenbroucke@kuleuven.be>

RUN apt update -y \
    && apt install -y apt-transport-https ca-certificates curl software-properties-common \
    && apt install -y default-jre-headless php7.0 php7.0-mysql libapache2-mod-php apache2 wget unzip \
    && apt install -y apt-utils dos2unix openssh-client debconf-utils

RUN { \
        echo debconf debconf/frontend select Noninteractive; \
        echo mysql-server mysql-server/root_password password 'root'; \
        echo mysql-server mysql-server/root_password_again password 'root'; \
    } | debconf-set-selections \
    && apt install -y mysql-server

RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 2930ADAE8CAF5059EE73BB4B58712A2291FA4AD5
RUN add-apt-repository "deb https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.6 multiverse"
RUN apt update -y && apt install -y mongodb-org
RUN mkdir -p /data/db

ADD entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN { \
        echo '<Directory /var/www/html/>'; \
        echo '  AllowOverride All'; \
        echo '</Directory>'; \
    } | tee "/etc/apache2/conf-available/docker-php.conf" \
    && a2enmod rewrite && a2enconf docker-php

ADD http://www.pdbmbook.com/static/pdbmbook.tar /pdbmbook.tar
RUN tar -xf /pdbmbook.tar -C /var/www/html

RUN sed -i 's/define("STANDALONE", false);/define("STANDALONE", true);/g' /var/www/html/configuration.php

ENV JAVA_HOME /usr
EXPOSE 80

CMD ["/entrypoint.sh"]
