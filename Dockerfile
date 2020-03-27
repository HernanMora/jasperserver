FROM tomcat:8.5-jre8

ENV JASPERSERVER_VERSION 7.1.1

ENV DB_TYPE mysql
ENV DB_HOST mysql
ENV DB_NAME jasperserver
ENV DB_PASSWORD mysql
ENV DB_PORT 3306
ENV DB_USER mysql

RUN apt-get update && apt-get install -y openjdk-8-jdk unzip xmlstarlet git postgresql-client vim

ADD resources/TIB_js-jrs-cp_${JASPERSERVER_VERSION}_bin.zip /tmp/jasperserver.zip

RUN unzip /tmp/jasperserver.zip -d /usr/src/ && \
   rm /tmp/jasperserver.zip && \
   mv /usr/src/jasperreports-server-cp-$JASPERSERVER_VERSION-bin /usr/src/jasperreports-server && \
   rm -r /usr/src/jasperreports-server/samples

COPY resources/postgresql-42.2.5.jar /usr/src/jasperreports-server/buildomatic/conf_source/db/postgresql/jdbc/postgresql-42.2.5.jar
COPY resources/mysql-connector-java-8.0.19.jar /usr/src/jasperreports-server/buildomatic/conf_source/db/mysql/jdbc/mysql-connector-java-8.0.19.jar

# Copy web.xml with cross-domain enable
ADD resources/web.xml /usr/local/tomcat/conf/

ADD scripts/entrypoint.sh /entrypoint.sh
ADD scripts/wait-for-it.sh /wait-for-it.sh

RUN chmod a+x /entrypoint.sh && chmod a+x /wait-for-it.sh

# If this file is present, then the JasperServer container will bootstrapp itself on startup.
# This file will get deleted once the bootstrap process is finished.
# If you want to re-bootstrap for any reason then recreate a file with the same name
# at the root of the jasperserver container and then restart the container.
RUN touch /.deploy

ENV JAVA_OPTS="-Xms1g -Xmx2g -XX:PermSize=32m -XX:MaxPermSize=512m -Xss2m -XX:+UseConcMarkSweepGC -XX:+CMSClassUnloadingEnabled"

# This volume allows JasperServer export zip files to be automatically imported when bootstrapping
VOLUME ["/jasperserver-import"]

EXPOSE 8080 8443

ENTRYPOINT ["/entrypoint.sh"]
