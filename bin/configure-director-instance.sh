#!/bin/bash
# This script takes a bare bones Centos 7 machine and installs and configures:
#   Cloudera Altus Director server and client
#   MariaDB for metadata
#   Bind9 to provide wildcard DNS for Cloudera Data Science Workbench

# echo 'Updating system prior to software installation'
# sudo yum -y update

# some necessary, some useful but optional
echo 'Installing tools'
sudo yum -y install wget curl telnet finger mlocate jq htop yum-cron tmux nc netcat nmap-ncat

echo 'installing Java 8 and disabling OpenJDK'
echo "exclude=jdk*,openjdk*" | sudo tee -a /etc/yum.conf
sudo yum remove --assumeyes *openjdk*
sudo yum -y install 'http://archive.cloudera.com/director6/6.0.0/redhat7/RPMS/x86_64/oracle-j2sdk1.8-1.8.0+update141-1.x86_64.rpm'
sudo alternatives --install /usr/bin/java java /usr/java/jdk1.8.0_141-cloudera/jre/bin/java 100
sudo rm -fv /usr/java/default /usr/java/latest
sudo ln -s /usr/java/jdk1.8.0_141-cloudera /usr/java/default
sudo ln -s /usr/java/jdk1.8.0_141-cloudera /usr/java/latest

echo 'installing Cloudera Altus Director 6 and supporting software'
(cd /tmp; wget 'http://archive.cloudera.com/director6/6.0.0/redhat7/cloudera-director.repo')
sudo mv -v /tmp/cloudera-director.repo /etc/yum.repos.d/
sudo yum -y install cloudera-director-server cloudera-director-client cloudera-director-plugins mysql-connector-java bind bind-utils mariadb mariadb-server psmisc git

echo 'Configuring MariaDB for use with CDH'
sudo service mariadb stop
echo """
  #
  # These groups are read by MariaDB server.
  # Use it for options that only the server (but not clients) should see
  #
  # See the examples of server my.cnf files in /usr/share/mysql/
  #

  # this is read by the standalone daemon and embedded servers
  [server]

  # this is only for the mysqld standalone daemon
  [mysqld]
  transaction-isolation = READ-COMMITTED
  # Disabling symbolic-links is recommended to prevent assorted security risks;
  # to do so, uncomment this line:
  # symbolic-links = 0

  key_buffer = 16M
  key_buffer_size = 32M
  max_allowed_packet = 32M
  thread_stack = 256K
  thread_cache_size = 64
  query_cache_limit = 8M
  query_cache_size = 64M
  query_cache_type = 1

  max_connections = 550
  #expire_logs_days = 10
  #max_binlog_size = 100M

  #log_bin should be on a disk with enough free space. Replace '/var/lib/mysql/mysql_binary_log' with an appropriate path for your system
  #and chown the specified folder to the mysql user.
  log_bin=/var/lib/mysql/mysql_binary_log

  binlog_format = mixed

  read_buffer_size = 2M
  read_rnd_buffer_size = 16M
  sort_buffer_size = 8M
  join_buffer_size = 8M

  # InnoDB settings
  innodb_file_per_table = 1
  innodb_flush_log_at_trx_commit  = 2
  innodb_log_buffer_size = 64M
  innodb_buffer_pool_size = 4G
  innodb_thread_concurrency = 8
  innodb_flush_method = O_DIRECT
  innodb_log_file_size = 512M

  [mysqld_safe]
  log-error=/var/log/mariadb/mariadb.log
  pid-file=/var/run/mariadb/mariadb.pid

  # this is only for embedded server
  [embedded]

  # This group is only read by MariaDB-5.5 servers.
  # If you use the same .cnf file for MariaDB of different versions,
  # use this group for options that older servers don't understand
  [mysqld-5.5]

  # These two groups are only read by MariaDB servers, not by MySQL.
  # If you use the same .cnf file for MySQL and MariaDB,
  # you can put MariaDB-only options here
  [mariadb]

  [mariadb-5.5]

  """ | sudo tee /etc/my.cnf.d/server.cnf

sudo service mariadb start
sudo chkconfig mariadb on


echo 'setting up cmdbadmin MariaDB user for admin'
echo "delete from mysql.user WHERE User=''; flush privileges;" | mysql -u root
echo "create database director character set utf8" | mysql -u root
echo "grant all privileges on *.* to 'cmdbadmin'@'%' identified by 'cmdbadmin' WITH GRANT OPTION" | mysql -u root
echo "flush privileges" | mysql -u root
# sudo /usr/bin/mysql_secure_installation <<EOF
# Y
# adminpass
# adminpass
# Y
# Y
# Y
# Y
# EOF

echo 'Configuring Altus Director to use MySQL/MariaDB'
echo """
  # Insure Java 8 is installed for *any* version of CM/CDH  - GJG
  lp.bootstrap.packages.cmJavaPackages[0]: ".*=oracle-j2sdk1.8"
  lp.bootstrap.packages.defaultCmJavaPackage: oracle-j2sdk1.8
  lp.database.type: mysql
  lp.database.username: cmdbadmin
  lp.database.password: cmdbadmin
  lp.database.host: `hostname -s`
  lp.security.bootstrap.admin.name: ${DIRECTOR_ADMIN_NAME:-admin}
  lp.security.bootstrap.admin.password: ${DIRECTOR_ADMIN_PASS:-admin}

  """ | sudo tee -a /etc/cloudera-director-server/application.properties

echo """
  lp.remote.username: admin
  lp.remote.password: admin
  """ | sudo tee -a /etc/cloudera-director-client/application.properties

echo """
  google {
    compute {
      imageAliases {
        centos6 = \"https://www.googleapis.com/compute/v1/projects/centos-cloud/global/images/centos-6-v20180611\",
        rhel6 = \"https://www.googleapis.com/compute/v1/projects/rhel-cloud/global/images/rhel-6-v20180611\",
        centos7 = \"https://www.googleapis.com/compute/v1/projects/centos-cloud/global/images/centos-7-v20180611\"
      }
      maxPollingIntervalSeconds = 8
      pollingTimeoutSeconds = 180
    }
  }
  """ | sudo tee /var/lib/cloudera-director-plugins/google-provider-2.0.0/etc/google.conf
sudo service cloudera-director-server start
sudo chkconfig cloudera-director-server on


echo 'Adding wildcard DNS to bind for *.cdsw.internal'
sudo mkdir -p /etc/named/zones
echo """
zone \"cdsw.internal.\" IN {
     type master;
     file \"/etc/named/zones/db.cdsw\";
     allow-update { 10.1.10.0/24; };
};
""" | sudo tee -a /etc/named/named.conf.local
echo """
\$ORIGIN .
\$TTL 600	; 10 minutes
cdsw.internal.	IN SOA	   gg-director.cdsw.internal. hostmaster.cdh-cluster.internal. (
				177         ; serial
				600        ; refresh (10 minutes)
				60         ; retry (1 minute)
				604800     ; expire (1 week)
				600        ; minimum (10 minutes)
				)
			NS	.
\$ORIGIN cdsw.internal.
    		A	10.0.0.6
*.cdsw.internal.                       A       10.0.0.6
""" | sudo tee /etc/named/zones/db.cdsw
# echo 'Adding rule to Dnsmasq to enable wildcard DNS for *.cdsw.internal'
# echo """
#   address=/.cdsw.internal/10.128.0.6
#   """ | sudo tee /etc/dnsmasq.d/cdsw-wildcard.conf
sudo service named restart

echo 'setting up Cloudera director-scripts'
(cd ~ ; wget 'https://github.com/cloudera/director-scripts.git')

echo 'Pulling a sample config to get you started'
cd ~

git clone 'https://github.com/gregoryg/macathon-director.git'

echo export PS1=\'\\u@azure-director \\W$ \' >> ~/.bashrc
# echo "All done!  Director UI will be running at http://`hostname -s`.cdh-cluster.internal:7189"
# echo 'If on Azure, remember to change DNS with director-scripts/azure-dns-scripts/bind-dns-setup.sh'
