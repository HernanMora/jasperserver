#!/bin/bash

# Sets script to fail if any command fails.
set -e

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

envs=(
    DB_TYPE
    DB_HOST
    DB_NAME
    DB_PASSWORD
    DB_PORT
    DB_USER
    ES_URL
    ES_LOG_LEVEL
    ES_LOG_FILE
    ES_USER
    ES_PASSWORD
)

for e in "${envs[@]}"; do
    file_env "$e"
done

# If environment is not set, uses default values for mysql
DB_TYPE=${DB_TYPE:-mysql}
DB_HOST=${DB_HOST:-mysql}
DB_NAME=${DB_NAME:-jasperserver}
DB_PASSWORD=${DB_PASSWORD:-mysql}
DB_PORT=${DB_PORT:-3306}
DB_USER=${DB_USER:-mysql}
ES_URL=${ES_URL:-localhost:9200}
ES_LOG_LEVEL=${ES_LOG_LEVEL:-INFO}
ES_LOG_FILE=${ES_LOG_FILE:-/tmp/elasticsearch.log}
ES_USER=${ES_USER:-}
ES_PASSWORD=${ES_USER:-}

# wait upto 30 seconds for the database to start before connecting
/wait-for-it.sh $DB_HOST:$DB_PORT -t 30

if [ -f "/.deploy" ]; then
    echo "JasperReports Server deploy........"

    pushd /usr/src/jasperreports-server/buildomatic

    if [ $DB_TYPE == "postgresql" ]; then
        cp sample_conf/postgresql_master.properties default_master.properties

        sed -i -e "s|^appServerType.*$|appServerType = tomcat8|g" default_master.properties
        sed -i -e "s|^appServerDir.*$|appServerDir = $CATALINA_HOME|g" default_master.properties
        sed -i -e "s|^dbHost.*$|dbHost=$DB_HOST|g" default_master.properties
        sed -i -e "s|^dbPort.*$|dbPort=$DB_PORT|g" default_master.properties
        sed -i -e "s|^dbUsername.*$|dbUsername=$DB_USER|g" default_master.properties
        sed -i -e "s|^dbPassword.*$|dbPassword=$DB_PASSWORD|g" default_master.properties
        sed -i -e "s|^js.dbName.*$|js.dbName=$DB_NAME|g" default_master.properties
        sed -i '/^# maven.jdbc.groupId=postgresql/s/^# //g' default_master.properties
        sed -i '/^# maven.jdbc.artifactId=postgresql/s/^# //g' default_master.properties
        sed -i -e "s|^# maven.jdbc.version=9.4-1210.jdbc41|maven.jdbc.version=42.2.5|g" default_master.properties
    fi

    if [ $DB_TYPE == "mysql" ]; then
        cp sample_conf/mysql_master.properties default_master.properties

        sed -i -e "s|^appServerType.*$|appServerType = tomcat8|g" default_master.properties
        sed -i -e "s|^appServerDir.*$|appServerDir = $CATALINA_HOME|g" default_master.properties
        sed -i -e "s|^dbHost.*$|dbHost=$DB_HOST|g" default_master.properties
        sed -i -e "s|^# dbPort.*$|dbPort=$DB_PORT|g" default_master.properties
        sed -i -e "s|^dbUsername.*$|dbUsername=$DB_USER|g" default_master.properties
        sed -i -e "s|^dbPassword.*$|dbPassword=$DB_PASSWORD|g" default_master.properties
        sed -i -e "s|^# js.dbName.*$|js.dbName=$DB_NAME|g" default_master.properties
        sed -i '/^# maven.jdbc.groupId=mysql/s/^# //g' default_master.properties
        sed -i '/^# maven.jdbc.artifactId=mysql-connector-java/s/^# //g' default_master.properties
        sed -i -e "s|# jdbcDriverClass=com.mysql.jdbc.Driver|jdbcDriverClass=com.mysql.cj.jdbc.Driver|g" default_master.properties
        sed -i -e "s|^# maven.jdbc.version=5.1.43-bin|maven.jdbc.version=8.0.19|g" default_master.properties
        sed -i -e "s|\&amp\;|\%3B|g" conf_source/db/mysql/db.template.properties
    fi

    sed -i -e "s|^# webAppNameCE.*$|webAppNameCE = ROOT|g" default_master.properties

    ./js-ant create-js-db || true #create database and skip it if database already exists
    ./js-ant init-js-db-ce
    ./js-ant import-minimal-ce
    ./js-ant deploy-webapp-ce

    rm /.deploy

    wget https://community.jaspersoft.com/sites/default/files/releases/jaspersoft_webserviceds_v1.5.zip -O /tmp/jasper.zip && \
    unzip /tmp/jasper.zip -d /tmp/ && \
    cp -rfv /tmp/JRS/WEB-INF/* $CATALINA_HOME/webapps/ROOT/WEB-INF/ && \
    sed -i 's/queryLanguagesPro/queryLanguagesCe/g' $CATALINA_HOME/webapps/ROOT/WEB-INF/applicationContext-WebServiceDataSource.xml && \
    rm -rf /tmp/*

    shopt -s nullglob

    TO_IMPORT=/jasperserver-import/*.zip
    for file in $TO_IMPORT
    do
      echo "Importing $file..."
      ./js-import.sh --input-zip $file
    done

    popd

    xmlstarlet ed --inplace -N x="http://java.sun.com/xml/ns/j2ee" --subnode "/x:web-app" --type elem -n "resource-ref-tmp" -v "" \
        --subnode "//resource-ref-tmp" --type elem -n "description" -v "JNDI Elasticsearch" \
        --subnode "//resource-ref-tmp" --type elem -n "res-ref-name" -v "jdbc/elasticsearch" \
        --subnode "//resource-ref-tmp" --type elem -n "res-type" -v "javax.sql.DataSource" \
        --subnode "//resource-ref-tmp" --type elem -n "res-auth" -v "Container" \
        -r //resource-ref-tmp -v resource-ref $CATALINA_HOME/webapps/ROOT/WEB-INF/web.xml

    xmlstarlet ed --inplace --subnode "/Context" -t elem -n ResourceTMP -v "" \
        -i //ResourceTMP -t attr -n "name" -v "jdbc/elasticsearch" \
        -i //ResourceTMP -t attr -n "auth" -v "Container" \
        -i //ResourceTMP -t attr -n "type" -v "javax.sql.DataSource" \
        -i //ResourceTMP -t attr -n "maxActive" -v "100" \
        -i //ResourceTMP -t attr -n "maxIdle" -v "30" \
        -i //ResourceTMP -t attr -n "maxWait" -v "10000" \
        -i //ResourceTMP -t attr -n "username" -v "$ES_USER" \
        -i //ResourceTMP -t attr -n "password" -v "$ES_PASSWORD" \
        -i //ResourceTMP -t attr -n "driverClassName" -v "com.amazon.opendistroforelasticsearch.jdbc.Driver" \
        -i //ResourceTMP -t attr -n "validationQuery" -v "" \
        -i //ResourceTMP -t attr -n "testOnBorrow" -v "true" \
        -i //ResourceTMP -t attr -n "url" -v "jdbc:elasticsearch://$ES_URL?logLevel=$ES_LOG_LEVEL&logOutput=$ES_LOG_FILE" \
        -r //ResourceTMP -v Resource $CATALINA_HOME/webapps/ROOT/META-INF/context.xml

    cp /usr/src/opendistro-sql-jdbc-1.3.0.0-SNAPSHOT.jar $CATALINA_HOME/lib

fi

# run Tomcat to start JasperServer webapp
catalina.sh run
