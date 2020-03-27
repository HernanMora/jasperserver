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

    xmlstarlet ed --inplace -N x="http://www.springframework.org/schema/beans" --subnode "/x:beans/x:bean[@id='jdbcDataSourceServiceFactory' and @class='com.jaspersoft.jasperserver.api.engine.jasperreports.service.impl.JdbcReportDataSourceServiceFactory']" -t elem -n propertyTMP -v "" \
        -i //propertyTMP -t attr -n "name" -v "defaultReadOnly" \
        -i //propertyTMP -t attr -n "value" -v "false" \
        -r //propertyTMP -v property $CATALINA_HOME/webapps/ROOT/WEB-INF/applicationContext.xml

fi

# run Tomcat to start JasperServer webapp
catalina.sh run
