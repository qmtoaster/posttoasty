setenforce 0
useradd -s /sbin/nologin -b /var/spool postfix
dnf -y install postfix postfix-mysql
dnf -y install mysql-server 
dnf -y dovecot dovecot-mysql
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
wget -P /var/qmail/bin  http://www.qmailtoaster.org/qmail-newu
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

cp /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.bak
cp dovecot.conf dovecot-sql.conf.ext /etc/dovecot
systemctl enable --now dovecot
#systemctl restart dovecot

cp /etc/postfix/main.cf /etc/postfix/main.cf.bak
cp /etc/postfix/master.cf /etc/postfix/master.cf.bak
cp main.cf /etc/postfix
cp master.cf /etc/postfix
systemctl enable --now postfix
#systemctl restart postfix
postmap /etc/postfix/virtual
service postfix reload

exit

/home/vpopmail/bin/vadddomain roosmem.org
/var/qmail/bin/qmail-newu

scp 192.168.9.4:/var/qmail/control/servercert.pem /var/qmail/control
ln -s /var/qmail/control/servercert.pem /var/qmail/control/clientcert.pem
