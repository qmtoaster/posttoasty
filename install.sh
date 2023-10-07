setenforce 0
useradd -s /sbin/nologin -b /var/spool postfix
dnf -y install postfix postfix-mysql mysql-server dovecot dovecot-mysql
dnf -y install http://repo.qmailtoaster.com/8/spl/sqlmd/mysql/testing/x86_64/vpopmail-5.4.33-5.qt.md.el8.x86_64.rpm

#chown -R postfix:root /var/spool/postfix
#chown -R postfix:postdrop /var/spool/postfix/maildrop
#chown -R postfix:postdrop /var/spool/postfix/public
#chown -R root:root /var/spool/postfix/pid
#chown root:root /var/spool/postfix
#chown postfix:root /var/lib/postfix
#chown postfix:postfix /var/lib/postfix/master*

groupadd -g 2108 -r qmail
mkdir -p /var/qmail/users
mkdir /var/qmail/control
mkdir /var/qmail/bin
chown root:qmail /var/qmail
chown root:qmail /var/qmail/control
chown root:qmail /var/qmail/users
wget -P /var/qmail/bin  https://github.com/qmtoaster/posttoasty/raw/main/qmail-newu
chmod 0700 /var/qmail/bin/qmail-newu
chown root:qmail /var/qmail/bin/qmail-newu

# MySQL admin password
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

mv /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.bak
wget -P /etc/dovecot https://raw.githubusercontent.com/qmtoaster/posttoasty/main/dovecot.conf
wget -P /etc/dovecot https://raw.githubusercontent.com/qmtoaster/posttoasty/main/dovecot-sql.conf.ext
systemctl enable --now dovecot
#systemctl restart dovecot

mv /etc/postfix/main.cf /etc/postfix/main.cf.bak
mv /etc/postfix/master.cf /etc/postfix/master.cf.bak
wget -P /etc/postfix https://raw.githubusercontent.com/qmtoaster/posttoasty/main/main.cf
wget -P /etc/postfix https://raw.githubusercontent.com/qmtoaster/posttoasty/main/master.cf
systemctl enable --now postfix
#systemctl restart postfix
postmap /etc/postfix/virtual
service postfix reload

wget -P /usr/local/bin https://raw.githubusercontent.com/qmtoaster/posttoasty/main/conntest

# Vpopmail add domain
read -p "Enter domain: " domain
if [ -z "$domain" ]; then
   echo "Empty domain, exiting..."
   exit 1
fi

/home/vpopmail/bin/vadddomain $domain
/var/qmail/bin/qmail-newu

#scp 192.168.9.4:/var/qmail/control/servercert.pem /var/qmail/control
#ln -s /var/qmail/control/servercert.pem /var/qmail/control/clientcert.pem
