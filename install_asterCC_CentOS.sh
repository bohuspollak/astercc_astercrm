#!/bin/bash

function pear_db_install(){
	echo -e "\e[32mStarting Install php-pear-DB\e[m"
	cd /usr/src
	if [ ! -e ./DB-1.7.13.tgz ]; then
		wget http://download.pear.php.net/package/DB-1.7.13.tgz
	fi
	pear install DB-1.7.13.tgz
}

function AMP_install() {
	echo -e "\e[32mStarting Install Apache+PHP+MySQL\e[m"
	yum -y install php-gd kernel-headers kernel-devel kernel-PAE kernel-PAE-devel httpd php php-mysql php-pear-DB doxygen mysql-server libtermcap-devel php-gd gcc gcc-c++ libxml2-devel php-pear php-posix sox make
	#Install LAMP (Apache, PHP and MySQL in Linux) using yum.
	echo -e "\e[32mAMP Install OK!\e[m"
	sed -i "s/post_max_size = 8M/post_max_size = 20M/" /etc/php.ini
	sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M/" /etc/php.ini
	sed -i "s/short_open_tag = Off/short_open_tag = On/" /etc/php.ini 
	sed -i "s/memory_limit = 16M /memory_limit = 128M /" /etc/php.ini 
	service mysqld start
}


function asterisk_install() {
	echo -e "\e[32mStarting Install Asterisk\e[m"
	useradd -c "Asterisk PBX" -d /var/lib/asterisk asterisk
	#Define a user called asterisk.
	mkdir /var/run/asterisk /var/log/asterisk /var/spool/asterisk -p
	#Change the owner of this file to asterisk.
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config 
	setenforce 0
	#shutdown selinux
	sed -i 's/^User apache/User asterisk/;s/^Group apache/Group asterisk/' /etc/httpd/conf/httpd.conf
	sed -i "s/AllowOverride None/AllowOverride All/" /etc/httpd/conf/httpd.conf
	service httpd restart
	#Change User apache and Group apache to User asterisk and Group asterisk. 
	#Change the default AllowOverride All to AllowOverride None to prevent .htaccess permission problems. 
	cd /usr/src
	if [ ! -e ./asterisk-$asteriskver.tar.gz ]; then
		wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-$asteriskver.tar.gz
		if [ ! -e ./asterisk-$asteriskver.tar.gz ]; then
			wget http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/asterisk-$asteriskver.tar.gz
		fi
	fi
	tar xf asterisk-$asteriskver.tar.gz
	if [ $? != 0 ]; then
		echo "fatal: dont have valid asterisk tar package"
		exit 1
	fi

	cd asterisk-$asteriskver
	./configure '-disable-xmldoc'
	make
	make install
	make samples
	#This command will  install the default configuration files.
	#make progdocs
	#This command will create documentation using the doxygen software from comments placed within the source code by the developers. 
	make config
	#This command will install the startup scripts and configure the system (through the use of the chkconfig command) to execute Asterisk automatically at startup.
	echo -e "\e[32mAsterisk Install OK!\e[m"
}

function libpri_install() {
	echo -e "\e[32mStarting Install LibPRI\e[m"
	cd /usr/src
	if [ ! -e ./libpri-$libpriver.tar.gz ]; then
		wget http://downloads.asterisk.org/pub/telephony/libpri/releases/libpri-$libpriver.tar.gz
	fi
	tar xf libpri-$libpriver.tar.gz
	if [ $? != 0 ]; then
		echo -e "fatal: dont have valid libpri tar package\n"
		exit 1
	fi

	cd libpri-$libpriver
	make
	make install
	echo -e "\e[32mLibPRI Install OK!\e[m"
}

function dahdi_install() {
	echo -e "\e[32mStarting Install DAHDI\e[m"
	cd /usr/src
	if [ ! -e ./dahdi-linux-complete-$dahdiver.tar.gz ]; then
		wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/dahdi-linux-complete-$dahdiver.tar.gz
		if [ ! -e ./dahdi-linux-complete-$dahdiver.tar.gz ]; then
			wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/releases/dahdi-linux-complete-$dahdiver.tar.gz
		fi
	fi
	tar xf dahdi-linux-complete-$dahdiver.tar.gz
	if [ $? != 0 ]; then
		echo -e "fatal: dont have valid dahdi tar package\n"
		exit 1
	fi

	cd dahdi-linux-complete-$dahdiver
	make clean
	make
	if [ $? != 0 ]; then
		yum -y upgrade
		echo -e "\e[32mplease reboot your server and run this script again\e[m\n"
		exit 1
	fi

	make install
	make config
	/usr/sbin/dahdi_genconf
	service dahdi start
	echo -e "\e[32mDAHDI Install OK!\e[m"
}


function freepbx_install() {
	echo -e "\e[32mStarting Install FreePBX\e[m"
	cd /usr/src
	if [ ! -e ./freepbx-$freepbxver.tar.gz ]; then
		wget http://mirror.freepbx.org/freepbx-$freepbxver.tar.gz
	fi
	tar xf freepbx-$freepbxver.tar.gz
	if [ $? != 0 ]; then
		echo -e "fatal: dont have valid freepbx tar package\n"
		exit 1
	fi

	cd freepbx-$freepbxver
	. /tmp/.mysql_root_pw.$$

	#Set mysql initial password.
	mysqladmin create asterisk -uroot -p$mysql_root_pw
	if [ $? != 0 ]; then
		echo -e "fatal: failed to create asterisk database\n"
		exit 1
	fi

	mysqladmin create asteriskcdrdb -uroot -p$mysql_root_pw
	mysql asterisk < SQL/newinstall.sql -uroot -p$mysql_root_pw
	mysql asteriskcdrdb < SQL/cdr_mysql_table.sql -uroot -p$mysql_root_pw
mysql -uroot -p$mysql_root_pw <<EOF
GRANT ALL PRIVILEGES ON asteriskcdrdb.* TO asterisk@localhost IDENTIFIED BY 'amp109';
GRANT ALL PRIVILEGES ON asterisk.* TO asterisk@localhost IDENTIFIED BY 'amp109';
flush privileges;
EOF
	#Create databases and import tables.
	./start_asterisk start
	echo -e "\e[32mYour IP Is `ifconfig|grep -oP \(\\\\d+?\\\\.\){3}\\\\d+|head -n1`,Password is $mysql_root_pw\nRemember This And press 'Enter' to start installation of FreePBX!\e[m"
	read pause
	./install_amp --username=asterisk --password=amp109 --webroot=/var/www/html
	#chmod -R 777 /var/www/html; 
	#Set permissions or HTTP error 403 forbidden.
	echo `wc -l /etc/asterisk/manager.conf` | awk '{system("head -n "$1-2" "$2">manager.tmp&&mv manager.tmp /etc/asterisk/manager.conf")}'
	#Delete last two lines of manager.conf or freepbx can't connect to the asterisk manager.
	sed -i 's/read = system,call,log,verbose,command,agent,user,config,command,dtmf,reporting,cdr,dialplan,originate/read = system,call,agent/' /etc/asterisk/manager.conf
	touch /etc/asterisk/sip_general_additional.conf
	touch sip_general_custom.conf
	touch /etc/asterisk/sip_general_custom.conf
	touch /etc/asterisk/sip_nat.conf
	touch /etc/asterisk/sip_registrations_custom.conf
	touch /etc/asterisk/sip_custom.conf
	touch /etc/asterisk/sip_custom_post.conf
	service asterisk restart
	sleep 1
	asterisk -rx 'module load chan_sip.so'
	asterisk -rx 'manager reload'
	#Load sip module then you can use sip command.
	asterisk -rx 'core set verbose 10'
	#Set level of verboseness.
	echo -e "\e[32mFreePBX Install OK!\e[m"
}

function lame_install(){
	echo -e "\e[32mStarting Install Lame for mp3 monitor\e[m"
	cd /usr/src
	if [ ! -e ./lame-$lamever.tar.gz ]; then
		wget http://sourceforge.net/projects/lame/files/lame/$lamever/lame-$lamever.tar.gz/download
	fi
	tar xf lame-$lamever.tar.gz
	if [ $? != 0 ]; then
		echo -e "\e[32mdont have valid lame tar package, you may lose the feature to check recordings on line\e[m\n"
		return 1
	fi

	cd lame-$lamever
	./configure && make && make install
	if [ $? != 0 ]; then
		echo -e "\e[32mfailed to install lame, you may lose the feature to check recordings on line\e[m\n"
		return 1
	fi
	ln -s /usr/local/bin/lame /usr/bin/
	return 0;
}

function get_mysql_passwd(){
	service mysqld start
	while true;do
		echo -e "\e[32mplease enter your mysql root passwd\e[m";
		read mysql_passwd;
		# make sure it's not a empty passwd
		if [ "X${mysql_passwd}" != "X" ]; then
			mysqladmin -uroot -p$mysql_passwd password $mysql_passwd	# try empty passwd
			if [ $? == 0  ]; then
				break;
			fi

			mysqladmin password "$mysql_passwd" 
			if [ $? == 0  ]; then
				break;
			fi

			echo -e "\e[32minvalid password,please try again\e[m"
		fi
	done
	echo mysql_root_pw=$mysql_passwd > /tmp/.mysql_root_pw.$$
}

function astercc_install() {
	while true;do
	echo -e "\e[32mDo you want do install Astercc? [y/N]\e[m";
	read yn;
	case $yn in
	[nN]*) return;; 
	*) break;;
	esac
	done
	echo -e "\e[32mStarting Install AsterCC\e[m"
	cd /usr/src
	if [ ! -e ./astercc-$asterccver.tar.gz ]; then
		wget http://sourceforge.net/projects/asterisk-crm/files/asterisk-crm/astercc-$asterccver.tar.gz/download
	fi
	ln -s  /var/www/html/admin/modules/core/etc/sip.conf /etc/asterisk/sip.conf
	ln -s  /var/www/html/admin/modules/core/etc/extensions.conf /etc/asterisk/extensions.conf
	tar xf astercc-$asterccver.tar.gz
	if [ $? != 0 ]; then
		echo "dont have valid astercc tar package"
		exit 1
	fi

	cd astercc-$asterccver
	chmod +x install.sh
	. /tmp/.mysql_root_pw.$$
	amiu=`sed '/^AMPMGRUSER=/!d;s/.*=//' /etc/amportal.conf`
	amipw=`sed '/^AMPMGRPASS=/!d;s/.*=//' /etc/amportal.conf`
	./install.sh -dbu=root -dbpw=$mysql_root_pw -amiu=$amiu -amipw=$amipw -allbydefault
	echo -e "\e[32mAsterCC Install OK!\e[m"
}

function run() {
	#wget http://astercc.org/download/asterccver0
	wget http://download1.astercc.org/asterccver0
	if [ ! -e ./asterccver0 ]; then
		echo "failed to get version infromation,please try again"
		exit 1;
	fi
	. ./asterccver0
	/bin/rm -rf ./asterccver0
	AMP_install
	libpri_install
	dahdi_install
	asterisk_install
	pear_db_install
	get_mysql_passwd
	freepbx_install
	lame_install
	astercc_install
	#Run all system after install.
	chkconfig dahdi on && chkconfig httpd on && chkconfig mysqld on && chkconfig asterisk on && chkconfig asterccd on
	#Run all automatically at linux startup.
	service iptables stop && chkconfig iptables off
	#Stop the internal firewall now and forever.
	service asterisk restart
	chown asterisk.asterisk /var/lib/php -R
	/bin/rm -rf /tmp/.mysql_root_pw.$$
	# update index.html
cat > /var/www/html/index.html << EOF
<HTML>
<HEAD>
<head>
    <title>FreePBX</title>
    <meta http-equiv="Content-Type" content="text/html">
    <link href="mainstyle.css" rel="stylesheet" type="text/css">
</head>

<body>
<div id="page">

<div class="header">

    <a href="index.php"><img src="admin/images/freepbx.png"/></a>

</div>

<div class="message">
	Welcome
</div>

<div class="content">

<h4><a href="recordings/">Voicemail & Recordings (ARI)</a></h4>
<h4><a href="panel/">Flash Operator Panel (FOP)</a></h4>
<h4><a href="admin/">FreePBX Administration</a></h4>
<h4><a href="astercc/astercrm">asterCRM</a></h4>
<h4><a href="astercc/asterbilling">asterBilling</a></h4>
<br><br><br><br><br><br>
</div>

	</div>

</body>
</html>
EOF

}

run