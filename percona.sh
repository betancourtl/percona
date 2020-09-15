#!/bin/bash

export DEBIAN_FRONTEND=noninteractive
export MYSQL_PWD=root

# Install noninteractive, prevent percona from opening the confirmation UI's
function remove_percona() {
  echo "uninstall_percona"
  sudo apt-get autoremove -y percona-server*
  sudo apt-get purge -yq percona-server*
}

function install_udf() {
  # try without username and pwd
  mysql -e "CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so'"
  mysql -e "CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so'"
  mysql -e "CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so'"

  # try with username and pwd
  mysql -uroot -p"$MYSQL_PWD" -e "CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so'"
  mysql -uroot -p"$MYSQL_PWD" -e "CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so'"
  mysql -uroot -p"$MYSQL_PWD" -e "CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so'"
}

function install5.6() {
  echo "install5.6"
  # Install the OS updates
  sudo apt-get update -y
  sudo apt-get upgrade -y

  # Set the timezone to CST
  sudo timedatectl set-timezone America/New_York

  timedatectl

  sudo dpkg-reconfigure -f noninteractive tzdata

  # Install needed packages
  sudo apt-get install gnupg2
  sudo apt-get install debconf-utils

  # Fetch the Percona repository
  wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb

  # Install the downloaded package with dpkg.
  sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb

  # Update the local cache
  sudo apt-get update -y

  # Install essential packages
  sudo apt-get -y install zsh htop

  # Install MySQL Server in a Non-Interactive mode. Default root password will be "root"
  sudo debconf-set-selections <<<"percona-server-server-5.6 percona-server-server/root_password password root"
  sudo debconf-set-selections <<<"percona-server-server-5.6 percona-server-server/root_password_again password root"

  sudo apt-get -y install percona-server-server-5.6

  # SQL statements to secure the installation
  mysql -uroot -p"$MYSQL_PWD" \
    <<EOF_MYSQL
UPDATE mysql.user SET Password = PASSWORD("$MYSQL_PWD") WHERE USER='root';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF_MYSQL

  sudo service mysql stop
  sudo service mysql start
}

function upgrade5.7() {
  echo "upgrade5.7"
  sudo service mysql stop
  sudo apt-get install -y percona-server-server-5.7
  sudo service mysql start
  install_udf
}

function upgrade8.0() {
  echo "upgrade8.0"
  wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
  sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
  sudo percona-release setup ps80
  sudo apt-get install percona-server-server -y
  install_udf
}

remove_percona
install5.6
upgrade5.7
upgrade8.0
