# Install script for posttoasty Postfix/Dovecot/Vpopmail mail server

#
# Disable Selinux
#
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

#
# Open necessary firewall ports
#
TAB="$(printf '\t')" && GREEN=$(tput setaf 2) && RED=$(tput setaf 1) && NORMAL=$(tput sgr0) && \
  systemctl start firewalld && systemctl enable firewalld && \
  ports=(20 21 22 25 80 89 110 113 143 443 465 587 993 995 3306) && \
  for index in ${!ports[*]}; do echo -n "Opening port: ${ports[$index]} : ";tput setaf 2;firewall-cmd --zone=public --add-port=${ports[$index]}/tcp --permanent;tput sgr0; done && \
  firewall-cmd --zone=public --add-port=53/udp --permanent && \
  echo -n "Reload firewall settings : " && tput setaf 2 && firewall-cmd --reload && tput sgr0

#
# Enable local name server
#
dnf -y install named bind-utils
sed -i 's/nameserver .*/nameserver 127.0.0.1/' /etc/resolv.conf
systemctl enable --now named

#
# Add postfix user...conflicts with vpopmail user
#
useradd -s /sbin/nologin -b /var/spool postfix

#
# Install mail server software
#
dnf -y install postfix postfix-mysql mysql-server dovecot dovecot-mysql
dnf -y install http://repo.qmailtoaster.com/8/spl/sqlmd/mysql/testing/x86_64/vpopmail-5.4.33-5.qt.md.el8.x86_64.rpm

#
# Add necessary vpopmail files and folders
#
groupadd -g 2108 -r qmail
mkdir -p /var/qmail/{users,control,bin}
wget -P /var/qmail/bin  https://github.com/qmtoaster/posttoasty/raw/main/qmail-newu
chmod 0700 /var/qmail/bin/qmail-newu
chown -R root:qmail /var/qmail
wget -P /var/qmail/control https://raw.githubusercontent.com/qmtoaster/posttoasty/main/servercert.pem

#
# Set MySQL password, start, and add vpopmail db
#
read -s -p "Enter mysqld password: " password
if [ -z "$password" ]; then
   echo "Empty password, exiting..."
   exit 1
fi
echo -e "\n"
MYSQLPW=$password
credfile=~/sql.cnf
echo -e "[client]\nuser=root\npassword='$MYSQLPW'\nhost=localhost" > $credfile
echo "Starting mysqld Server..."
systemctl enable --now mysqld
echo "Started mysqld Server"
sleep 2
echo "Setting mysqld admin password..."
mysqladmin -uroot password $MYSQLPW &> /dev/null
echo "Admin password set"
echo "Creating vpopmail database..."
mysqladmin --defaults-extra-file=$credfile reload
mysqladmin --defaults-extra-file=$credfile refresh
mysqladmin --defaults-extra-file=$credfile create vpopmail
mysqladmin --defaults-extra-file=$credfile reload
mysqladmin --defaults-extra-file=$credfile refresh
echo "Adding vpopmail users and privileges..."
mysql --defaults-extra-file=$credfile -e "CREATE USER vpopmail@localhost IDENTIFIED BY 'SsEeCcRrEeTt'"
mysql --defaults-extra-file=$credfile -e "GRANT ALL PRIVILEGES ON vpopmail.* TO vpopmail@localhost"
mysqladmin --defaults-extra-file=$credfile reload
mysqladmin --defaults-extra-file=$credfile refresh
echo "Done with vpopmail database..."

#
# Get Dovecot files and start 
#
mv /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.bak
wget -P /etc/dovecot https://raw.githubusercontent.com/qmtoaster/posttoasty/main/dovecot.conf
wget -P /etc/dovecot https://raw.githubusercontent.com/qmtoaster/posttoasty/main/dovecot-sql.conf.ext
wget -P /etc/dovecot https://raw.githubusercontent.com/qmtoaster/posttoasty/main/dh.pem
systemctl enable --now dovecot

#
# Get Postfix files, set local subnet, and start
#
mv /etc/postfix/main.cf /etc/postfix/main.cf.bak
mv /etc/postfix/master.cf /etc/postfix/master.cf.bak
wget -P /etc/postfix https://raw.githubusercontent.com/qmtoaster/posttoasty/main/main.cf
wget -P /etc/postfix https://raw.githubusercontent.com/qmtoaster/posttoasty/main/master.cf
wget -P /etc/postfix https://raw.githubusercontent.com/qmtoaster/posttoasty/main/alias-maps.cf
wget -P /etc/postfix https://raw.githubusercontent.com/qmtoaster/posttoasty/main/domain-maps.cf
wget -P /etc/postfix https://raw.githubusercontent.com/qmtoaster/posttoasty/main/virtual-maps.cf
network=`ip -o -f inet addr show | awk '/scope global/ {print $4}' | sed 's#[0-9]*/#0/#g'`
sed -i "s,^mynetworks.*,mynetworks = $network," main.cf
postmap /etc/postfix/virtual
systemctl enable --now postfix

#
# Download test script
#
wget -P /usr/local/bin https://raw.githubusercontent.com/qmtoaster/posttoasty/main/conntest
chmod 755 /usr/local/bin/conntest

#
# Vpopmail add domain, create necessary aliases so postfix delivers mail, and update vpopmail backend files
#
read -p "Enter domain: " domain
if [ -z "$domain" ]; then
   echo "Empty domain, exiting..."
   exit 1
fi
/home/vpopmail/bin/vadddomain $domain
/home/vpopmail/bin/valias -i postmaster@$domain mailer-daemon@localhost.localdomain
/home/vpopmail/bin/valias -i postmaster@$domain anonymous@localhost.localdomain
/home/vpopmail/bin/valias -i postmaster@$domain root@localhost.localdomain
/var/qmail/bin/qmail-newu

#
# Perform connection test
#
conntest

exit 0
