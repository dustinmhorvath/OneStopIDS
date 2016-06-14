MYSQLROOTPASSWD=passw0rd
SNORBYDBPASS=passw0rd

set -e

# You need to be root, sorry.
if [[ $EUID -ne 0 ]]; then
	echo "This script requires elevated privileges to run. Are you root?"
	exit
fi

DATE=$(date +"%Y%m%d%H%M")

echo "Installing snorby package dependencies..."
apt-get install wkhtmltopdf gcc g++ build-essential libssl-dev libreadline6-dev zlib1g-dev libsqlite3-dev libxslt-dev libxml2-dev imagemagick git-core libmysqlclient-dev libmagickwand-dev default-jre ruby ruby-dev -y > /dev/null
echo "Done."
echo "Installing MySQL server..."
debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQLROOTPASSWD"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQLROOTPASSWD"
sudo apt-get -y install mysql-server > /dev/null
echo "Done."

echo "Installing snorby gem dependencies..."
gem install thor i18n bundler tzinfo builder memcache-client rack rack-test erubis mail rack-mount rails sqlite3 > /dev/null

echo "Installing Suricata..."
apt-get install suricata -y > /dev/null
echo "Done."

if [ -d "/var/www/snorby" ]; then
  mv /var/www/snorby /var/www/snorby.BAK.$DATE
fi
git clone http://github.com/Snorby/snorby.git /var/www/snorby

echo "Building configurations for Snorby..."
cp /var/www/snorby/config/database.yml.example /var/www/snorby/config/database.yml
cp /var/www/snorby/config/snorby_config.yml.example /var/www/snorby/config/snorby_config.yml

sed -i "s/password: .*\$/password: $MYSQLROOTPASSWD/" /var/www/snorby/config/database.yml
sed -i "s/domain: .*\$/domain: 'localhost:3000'/" /var/www/snorby/config/snorby_config.yml
sed -i "s/wkhtmltopdf: .*\$/wkhtmltopdf: wkhtmltopdf/" /var/www/snorby/config/snorby_config.yml

if grep -Fxq "/etc/suricata/rules/" /var/www/snorby/config/snorby_config.yml
then
  echo "Rules already in snorby config."
else
  sed -i "s#rules:#rules: \n    - \"/etc/suricata/rules/\"#g" /var/www/snorby/config/snorby_config.yml
fi
echo "Done."


cd /var/www/snorby
echo "Updating snorby configuration and getting dependencies..."
bundle update activesupport railties rails > /dev/null
echo "Installing dependencies..."
gem install arel ezprint > /dev/null
echo "Bundle installing..."
bundle install > /dev/null
echo "Setting up Snorby..."
bundle exec rake snorby:setup > /dev/null
echo "Done."

echo "Creating MySQL User for snorby..."
mysql -u root --password=$MYSQLROOTPASSWD -e "GRANT ALL PRIVILEGES ON snorby.* TO 'snorbyuser'@'localhost' IDENTIFIED BY '$SNORBYDBPASS' with grant option;"
mysql -u root --password=$MYSQLROOTPASSWD -e "grant all privileges on snorby.* to 'snorbyuser'@'localhost' with grant option;"
mysql -u root --password=$MYSQLROOTPASSWD -e "flush privileges;"

echo "Correcting snorby database config with new user..."
sed -i "s/password: .*\$/password: $SNORBYDBPASS/" /var/www/snorby/config/database.yml
sed -i "s/username: .*\$/username: snorbyuser/" /var/www/snorby/config/database.yml
echo "Done."

echo "Configuring MySQL listen..."
sed -i 's/bind-address\s\+.*/bind-address = 0.0.0.0/g' /etc/mysql/my.cnf

service mysql restart
echo "Installing Apache2..."
apt-get install apache2 apache2-dev libapr1-dev libaprutil1-dev libcurl4-openssl-dev > /dev/null
service apache2 start

echo "Installing Passenger gem..."
gem install --no-ri --no-rdoc passenger > /dev/null
echo "Installing Passenger..."
/usr/local/bin/passenger-install-apache2-module -a &> /tmp/.passenger_compile_out
echo "Done."

sed -n '/LoadModule passenger_module \/var\//,/<\/IfModule>/p' /tmp/.passenger_compile_out > /etc/apache2/mods-available/passenger.load
a2enmod passenger
a2enmod rewrite
a2enmod ssl
rm /tmp/.passenger_compile_out

chown www-data:www-data /var/www/snorby -R

echo "Writing new apache config..."
cat <<EOT >> /etc/apache2/sites-available/snorby.conf

<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/snorby/public

        <Directory "/var/www/snorby/public">
                AllowOverride all
                Order deny,allow
                Allow from all
                Options -MultiViews
        </Directory>

</VirtualHost>

EOT

a2dissite 000-default.conf
a2ensite snorby.conf

service apache2 restart

cd /var/www/snorby
echo "Bundle packing snorby..."
bundle pack > /dev/null
echo "Installing snorby..."
bundle install --path vender/cache > /dev/null
echo "Done.\n"

echo "Installing Barnyard2 dependencies..."
apt-get install libpcre3 libpcre3-dbg libpcre3-dev build-essential autoconf automake libtool libpcap-dev libnet1-dev libyaml-0-2 libyaml-dev zlib1g zlib1g-dev libcap-ng-dev libcap-ng0 make libmagic-dev git pkg-config libnss3-dev libnspr4-dev wget mysql-client libmysqlclient-dev libmysqlclient18 -y > /dev/null
echo "Got Barnyard2 dependencies.\n"

cd /tmp
echo "Getting OISF source..."
if [ -d "/tmp/oisf" ]; then
  rm -r /tmp/oisf
fi
git clone git://phalanx.openinfosecfoundation.org/oisf.git > /dev/null
cd oisf
git clone https://github.com/OISF/libhtp.git > /dev/null
echo "Setting up oisf..."
./autogen.sh > /dev/null
echo "Confguring..."
./configure --with-libnss-libraries=/usr/lib --with-libnss-includes=/usr/include/nss/ --with-libnspr-libraries=/usr/lib --with-libnspr-includes=/usr/include/nspr > /dev/null
echo "Cleaning oisf..."
make clean > /dev/null
echo "Making..."
make > /dev/null
echo "Installing oisf..."
make install-full > /dev/null
ldconfig
echo "OISF done.\n"

echo "Installing DAQ dependencies..."
apt-get install flex bison -y > /dev/null
cd /tmp
echo "Getting daq-2.0.6 source..."
wget https://www.snort.org/downloads/snort/daq-2.0.6.tar.gz > /dev/null
if [ -d "/tmp/daq-2.0.6" ]; then
  rm -r /tmp/daq-2.0.6
fi
tar xzf daq-2.0.6.tar.gz > /dev/null
cd daq-2.0.6
echo "Configuring..."
./configure > /dev/null
echo "Compiling daq-206..."
make > /dev/null
echo "Installing daq..."
make install > /dev/null

echo "Gitting Barnyard2..."
git clone https://github.com/firnsy/barnyard2 > /dev/null
cd barnyard2
echo "Setting up..."
./autogen.sh > /dev/null
echo "Configuring Barnyard2..."
./configure #NOTE: --with-mysql here? > /dev/null
ln -s /usr/include/dumbnet.h /usr/include/dnet.h
echo "Compiling Barnyard2..."
make > /dev/null
echo "Installing Barnyard2..."
make install > /dev/null
cp /tmp/barnyard2/etc/barnyard2.conf /etc/suricata/
echo "Done."

sed -i "s#config reference_file:\s\+ /etc/.*#config reference_file:      /etc/suricata/reference.config#g" /etc/suricata/barnyard2.conf
sed -i "s#config classification_file:\s\+ /etc/.*#config classification_file: /etc/suricata/classification.config#g" /etc/suricata/barnyard2.conf
sed -i "s#config gen_file:\s\+ /etc/.*#config gen_file:            /etc/suricata/rules/gen-msg.map#g" /etc/suricata/barnyard2.conf
sed -i "s#config sid_file:\s\+ /etc/.*#config sid_file:            /etc/suricata/rules/sid-msg.map#g" /etc/suricata/barnyard2.conf

if grep -Fxq "user=snorbyuser" /etc/suricata/barnyard2.conf
then
  echo "Output database already configured."
else
  echo "output database: log, mysql, user=snorbyuser password=$SNORBYDBPASS dbname=snorby host=localhost sensor_name=sensor1" >> /etc/suricata/barnyard2.conf
fi

if [ ! -d "/var/log/barnyard2" ]; then
  mkdir /var/log/barnyard2
fi

sed -i "s#RUN=.*#RUN=yes#g" /etc/default/suricata
sed -i "s#LISTENMODE=.*#LISTENMODE=af-packet#g" /etc/default/suricata
sed -i "s#SURCONF=.*#SURCONF=/etc/suricata/suricata.yaml#g" /etc/default/suricata
cp suricata-debian.yaml suricata.yaml

#NOTE doesn't seem to run, but w/e, will deal with later
sed -i "s|windows: [0.0.0.0/0].*|#windows: [0.0.0.0/0]|g" /etc/suricata/suricata.yaml 

wget http://rules.emergingthreats.net/open/suricata/emerging.rules.tar.gz
tar xzf emerging.rules.tar.gz /etc/suricata/rules/
rm emerging.rules.tar.gz

suricata -c /etc/suricata/suricata.yaml -i eth0 -D
barnyard2 -c /etc/suricata/barnyard2.conf -d /var/log/suricata -f unified2.alert -w /var/log/suricata/suricata.waldo -D

echo "Writing barnyard init.d..."
cat <<EOT >> /etc/init.d/barnyard2
#!/bin/sh
case $1 in
    start)
        echo "starting $0..."
        sudo barnyard2 -c /etc/suricata/barnyard2.conf -d /var/log/suricata -f unified2.alert -w /var/log/suricata/suricata.waldo
        echo -e 'done.'
    ;;
    stop)
        echo "stopping $0..."
        killall barnyard2
        echo -e 'done.'
    ;;
    restart)
        $0 stop
        $0 start
    ;;
    *)
        echo "usage: $0 (start|stop|restart)"
    ;;
esac

EOT

chmod 700 /etc/init.d/barnyard2
update-rc.d barnyard2 defaults 21 00
