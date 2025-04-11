#!/bin/bash

function AMP_install() {
	echo -e "\e[32mStarting Install Apache+PHP+MySQL\e[m"
	apt-get -y install apache2 php5 php5-mysql php5-gd php-pear mysql-server ncurses-dev build-essential gcc sox chkconfig make bison flex build-essential linux-source linux-image-$(uname -r) make
	pear install db
	mkdir /var/www/html -p
	sed -i "s/\/var\/www/\/var\/www\/html/" /etc/apache2/sites-enabled/000-default

	#Install LAMP (Apache, PHP and MySQL in Linux) using apt-get.
	echo -e "\e[32mAMP Install OK!\e[m"
}


function asterisk_install() {
	cd /usr/src
	echo -e "\e[32mStarting Install Asterisk\e[m"
	useradd -c "Asterisk PBX" -d /var/lib/asterisk asterisk
	mkdir /var/run/asterisk /var/log/asterisk
	chown asterisk:asterisk /var/run/asterisk /var/log/asterisk /var/lib/php5 -R
	
	sed -i "/User/d" /etc/apache2/httpd.conf
	sed -i "/Group/d" /etc/apache2/httpd.conf
	echo -e "User asterisk\nGroup asterisk" >> /etc/apache2/httpd.conf
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
		apt-get -y upgrade
		echo -e "\e[32mplease reboot your server and run this script again\e[m\n"
		exit 1
	fi

	make install
	make config
	/usr/sbin/dahdi_genconf
	/etc/init.d/dahdi start
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
	#Set permissions or HTTP error 403 forbidden.
	echo `wc -l /etc/asterisk/manager.conf` | awk '{system("head -n "$1-2" "$2">manager.tmp&&mv manager.tmp /etc/asterisk/manager.conf")}'
	#Delete last two lines of manager.conf or freepbx can't connect to the asterisk manager.
	sed -i 's/read = system,call,log,verbose,command,agent,user,config,command,dtmf,reporting,cdr,dialplan,originate/read = system,call,agent/' /etc/asterisk/manager.conf
	/var/lib/asterisk/bin/retrieve_conf
	touch /etc/asterisk/sip_general_additional.conf
	touch sip_general_custom.conf
	touch /etc/asterisk/sip_general_custom.conf
	touch /etc/asterisk/sip_nat.conf
	touch /etc/asterisk/sip_registrations_custom.conf
	touch /etc/asterisk/sip_custom.conf
	touch /etc/asterisk/sip_custom_post.conf

	service asterisk restart
	sleep 1
	asterisk -rx 'manager reload'
	asterisk -rx 'core set verbose 10'
	#Set level of verboseness.
	echo -e "\e[32mFreePBX Install OK!\e[m"
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
		wget http://sourceforge.net/projects/asterisk-crm/files/asterisk-crm/astercc-$asterccver.tar.gz/download -O astercc-$asterccver.tar.gz
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

function get_mysql_passwd(){
	service mysql start
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

function lame_install(){
	echo -e "\e[32mStarting Install Lame for mp3 monitor\e[m"
	cd /usr/src
	if [ ! -e ./lame-$lamever.tar.gz ]; then
		wget http://sourceforge.net/projects/lame/files/lame/$lamever/lame-$lamever.tar.gz/download -O lame-$lamever.tar.gz
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
	echo -e "\e[32mLame install OK!\e[m"
	return 0;
}

function run() {
	cd /usr/src
	wget http://astercc.org/download/asterccver0
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
	get_mysql_passwd
	freepbx_install
	lame_install
	astercc_install
	chown asterisk.asterisk /var/www/html -R
	#Run all automatically at linux startup.
	chkconfig apache2 on
	chkconfig asterisk on
	ln -s /opt/asterisk/scripts/astercc/asterccd /etc/init.d/
	update-rc.d dahdi defaults
	update-rc.d mysql defaults
	update-rc.d asterccd defaults
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