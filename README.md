# JasperReports&reg; Server + Postgresql/MySQL Server for Docker - Open Distro for Elasticsearch JDBC datasource

# Introduction

Basic knowledge of Docker and the underlying infrastructure is required.
For more information about Docker see the
[official documentation for Docker](https://docs.docker.com/).

For more information about JasperReports Server, see the
[Jaspersoft community](http://community.jaspersoft.com/).

For more information about Open Distro for Elasticsearch, see the
[Open Distro for Elasticsearch Documentation](https://opendistro.github.io/for-elasticsearch-docs/)

# Prerequisites

The following software is required or recommended:

- [docker-engine](https://docs.docker.com/engine/installation) version 1.12 or higher
- (*recommended*):
  - [Docker Desktop for Windows](https://docs.docker.com/docker-for-windows/install/)
  - [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/install/)
- (*recommended*) [docker-compose](https://docs.docker.com/compose/install) version 1.12 or higher

# Installation

## Get the jasperserver-community-mysql Dockerfile and supporting resources

Download the jasperserver-community-postgresql repository as a zip and unzip it, or clone the repository from Github,
which will install the jasperserver-community-postgresql files on to your machine.

```console
$ git clone https://github.com/HernanMora/jasperserver-community-postgresql.git
$ cd jasperserver-community-mysql
$ git checkout opendistro_datasource
```

## The installed Repository structure

After getting the jasperserver-community-postgresql github repository, the following files are placed
on your machine:

- `Dockerfile` - container build commands
- `docker-compose.yml` - sample configuration for building and running via
docker-compose
- `.env` - sample file with environment variables for docker-compose
- `README.md` - this document
- `resources\` - directory where you put your JasperReports Server zip file
or other files you want to copy to the container
- `scripts\`
  - `entrypoint.sh` - sample runtime configuration for starting and running
JasperReports Server from the shell
  - `wait-for-it.sh` - Waits for the database to start before connecting to it using [wait-for-it](https://github.com/vishnubob/wait-for-it) as recommended by [docker-compose documentation](https://docs.docker.com/compose/startup-order/). 

## Downloading JasperReports Server WAR

Download the JasperReports Server WAR File installer zip archive from the TIBCO eDelivery
or build it from a bundled installer [Jaspersoft Community Wiki article](https://community.jaspersoft.com/wiki/creating-jasperreports-server-war-file-installer-bundled-installer)

Copy the installer zip file to the `resources` directory below where the Dockerfile is.
For example, if you have downloaded the zip to your ~/Downloads directory:

```console
$ cp ~/Downloads/TIB_js-jrs-cp_<JASPERSERVER_VERSION>_bin.zip resources/
```

Modify the `JASPERSERVER_VERSION` environment variable in the Dockerfile file with the corresponding Jasper Server Community version.


# Build-time environment variables
At build time, JasperReports Server uses the following environment variables.
These variables can be set directly in the `Dockerfile`.
In addition, if you are using docker-compose, many of these variables
can be set in the `docker-compose.yml` or the `.env` file.
See the
[Compose file reference](https://docs.docker.com/compose/compose-file/#/args)
for more information:

- `DB_TYPE` - database type [mysql|postgresl]. Default: mysql
- `DB_USER` - database username. Default: mysql
- `DB_PASSWORD` - database password. Default: mysql
- `DB_HOST` - database host. Default: mysql
- `DB_PORT` - database port. Default: 3306
- `DB_NAME` - JasperReports Server database name. Default: jasperserver

# Build and run

## <a name="compose"></a>Building and running with docker-compose (recommended)

`docker-compose.yml` provides a sample
[Compose](https://docs.docker.com/compose/compose-file/) implementation of
JasperReports Server.

To build and run using `docker-compose.yml`, execute the following commands in
the root directory of your repository:

```console
$ docker-compose build
$ docker-compose up -d
```

# Logging

There are multiple options for log access, aggregation, and management
in the Docker ecosystem. The most common options are:

- volumizing log files
- using docker [logging drivers](
https://docs.docker.com/engine/admin/logging/overview/)

For the TIBCO JasperReports Server Docker, the default `json-file`
docker drivers should be sufficient.
In a more complex environment a log collector should be considered. One
example is collecting logs on a remote syslog server.
See the
[logging drivers](https://docs.docker.com/engine/admin/logging/overview/)
documentation for
more information.

To volumize the JasperReports Server container log, you can create a container
for log storage:

```console
$ docker volume create --name my-jasperserver-log
$ docker run --name my-jasperserver -v \
my-jasperserver-log:/usr/local/tomcat/webapps/jasperserver/WEB-INF/logs \
-p 8080:8080 -d local/jasperserver:7.1.1
```
Where:

- `my-jasperserver-log` is the name of the new data volume for log storage.
- `my-jasperserver` is the name of the new JasperReports Server container
- `local/jasperserver:7.1.1`  is the image name and version tag.
for your build. This image will be used to create containers.
- Database settings should be modified for your setup.

Note that docker containers do not have separate logs. All information is
logged via the driver or application. In the case of the JasperReports
Server container, the main log is output by Tomcat to the docker-engine
via the logging driver, and the application log specific to
JasperReports Server is output to
`my-jasperserver-log:/usr/local/tomcat/webapps/jasperserver/WEB-INF/logs`

# Updating Tomcat

The JasperReports Server container is based on the
[tomcat:8.5-jre8](tomcat:8.5-jre8) (Apache Tomcat) image from
[Docker Hub](https://hub.docker.com).
To upgrade your JasperReports Server base image, you
must rebuild the JasperReports Server image with the newer Tomcat. See
[Build and run](#build-and-run) for building instructions.

To update an already existing JasperReports Server container to
a newer base image, you have to re-create it. If you are using volumes
for JasperReports Server, you can preserve web application data between
upgrades.

# Import resources

You can import any zip file from another JasperReports Server with the special volume `/jasperserver-import` from 
container on deploy.

For example:
```console
$ docker volume create --name my-jasperserver-imports
$ sudo cp import-resource.zip \
/var/lib/docker/volumes/my-jasperserver-imports/_data
$ docker run --name my-jasperserver -v \
my-jasperserver-imports:\
/jasperserver-import \
-p 8080:8080 -d local/jasperserver:7.1.1
```
Where:

- `my-jasperserver-imports` is the name of the import
data volume.
- `import-resource.zip` is an archive containing resources
- `/var/lib/docker/volumes/my-jasperserver-imports/_data` is an
example path. Use `docker volume inspect`
to get the local path to the volume for your system.
- `my-jasperserver` is the name of the JasperReports Server
container.
- `local/jasperserver:7.1.1` is an image name and version tag that is used
as a base for the new container.
- Database settings should be modified for your setup.


#Logging in

To log into JasperReports Server on any operating system:

1. Start JasperReports Server.
2. Open a supported browser: Firefox, Internet Explorer, Chrome, or Safari.
3. Log into JasperReports Server by entering the startup URL in your
browser's address field.
The URL depends upon your installation. The default configuration uses:

```
http://localhost:8080/
```

Where:

- localhost is the name or IP address of the computer hosting JasperReports Server.
- 8080 is the port number for the Apache Tomcat application server. 
If you used a different port when installing your application server, 
specify its port number instead of 8080.

JasperReports Server ships with the following default credentials:

- superuser/superuser - System-wide administrator
- jasperadmin/jasperadmin - Administrator for the default organization


## Docker documentation
For additional questions regarding docker and docker-compose usage see:
- [docker-engine](https://docs.docker.com/engine/installation) documentation
- [docker-compose](https://docs.docker.com/compose/overview/) documentation

# Copyright

TIBCO, Jaspersoft, and JasperReports are trademarks or
registered trademarks of TIBCO Software Inc.
in the United States and/or other countries.

Docker is a trademark or registered trademark of Docker, Inc.
in the United States and/or other countries.


