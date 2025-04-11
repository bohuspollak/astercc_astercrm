#!/bin/bash

# Auto install astercc commercial and related packages
# By Solo #### solo@astercc.org last modify 2012-04-17
# By Solo #### solo@astercc.org last modify 2013-02-06 for asterCC 1.2-beta
# By Solo #### solo@astercc.org last modify 2013-05-20, 修正了asterisk总是使用asterccuser asterccsecret作为AMI用户的bug
# By Solo #### solo@astercc.org last modify 2014-02-07, 禁用了netjet dahdi驱动
# 2015-10-08 改用mysql 5.6
# 2016-02-08 增加了logrotate配置

#downloadmirror=http://download1.astercc.org

#downloadmirror=http://astercc.org/download
#downloadmirror=http://download3.astercc.org

# uname -r, 如果包含-pve, 需要到/usr/src执行
# ln -s kernels/2.6.18-308.4.1.el5-x86_64/ linux 

function newRepo_install(){
    cd /usr/src
    version=`cat /etc/issue|grep -o 'release [0-9]\+'`
    arch=i386
    bit=`getconf LONG_BIT`
    if [ $bit == 64 ]; then
        arch=x86_64
    fi;
    #if [ "$version" == "release 6" ]; then
    #    if [ ! -e ./epel-release-$epelver6.noarch.rpm ]; then
    #        wget http://dl.iuscommunity.org/pub/ius/stable/Redhat/6/$arch/epel-release-$epelver6.noarch.rpm
    #    fi;

    #    if [ ! -e ./ius-release-$iusver6.ius.el6.noarch.rpm ]; then
    #        wget http://dl.iuscommunity.org/pub/ius/stable/Redhat/6/$arch/ius-release-$iusver6.ius.el6.noarch.rpm
    #    fi;
    #    rpm -e epel-release*
    #    rpm -ivh epel-release-$epelver6.noarch.rpm
    #    rpm -ivh ius-release-$iusver6.ius.el6.noarch.rpm;
    #else
    #    if [ ! -e ./epel-release-$epelver5.noarch.rpm ]; then
    #        wget http://dl.iuscommunity.org/pub/ius/archive/Redhat/5/$arch/epel-release-$epelver5.noarch.rpm
    #    fi;

    #    if [ ! -e ./ius-release-$iusver5.ius.el5.noarch.rpm ]; then
    #        wget http://dl.iuscommunity.org/pub/ius/archive/Redhat/5/$arch/ius-release-$iusver5.ius.el5.noarch.rpm
    #    fi;

    #    rpm -ivh epel-release-$epelver5.noarch.rpm ius-release-$iusver5.ius.el5.noarch.rpm;

    #fi
    #set -eu

    if [[ $UID -ne 0 ]]; then
        echo "this script requires root privileges" >&2
        exit 1
    fi

    if [[ ! -e /etc/redhat-release ]]; then
        echo "not an EL distro"
        exit 1
    fi

    #RELEASEVER=$(rpm --eval %rhel)

    if [[ $RELEASEVER -ne 6 ]] && [[ $RELEASEVER -ne 7 ]]; then
        echo "unsupported OS version"
        exit 1
    fi
    rpm --import https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-$RELEASEVER https://repo.ius.io/RPM-GPG-KEY-IUS-$RELEASEVER
    yum --assumeyes install https://dl.fedoraproject.org/pub/epel/epel-release-latest-$RELEASEVER.noarch.rpm https://repo.ius.io/ius-release-el$RELEASEVER.rpm

    sed -i "s/mirrorlist/#mirrorlist/" /etc/yum.repos.d/ius.repo
    sed -i "s/#baseurl/baseurl/" /etc/yum.repos.d/ius.repo
    #sed -i "s/stable/archive/g" /etc/yum.repos.d/ius.repo
}

function yum_install(){
    #yum -y upgrade
        #yum -y upgrade
        yum -y remove php*
        yum -y remove asterisk*
        
        if [ $RELEASEVER -eq 6 ]; then
            yum -y remove mysql*
            yum -y install mysql56u-server mysql56u-devel
        else
            yum -y remove mariadb*
            yum -y install mariadb${mariadbver}-server mariadb${mariadbver}-devel
        fi
        yum -y install mailx cpan crontabs glibc gcc-c++ libtermcap-devel newt newt-devel ncurses ncurses-devel libtool libxml2-devel kernel-devel kernel-PAE-devel subversion flex libstdc++-devel libstdc++  unzip sharutils openssl-devel make postfix redis bzip2 net-tools 
        yum -y install kernel-headers gcc perl
        yum -y install ghostscript ntp
        if [ $RELEASEVER -eq 6 ]; then
            chkconfig mysqld on
            chkconfig crond on
            service crond start
        else
            systemctl enable mariadb
            systemctl enable crond
            systemctl start crond
        fi
}

function php_install(){
    echo -e "\e[32mStarting Install PHP-Fpm\e[m"
    if [ -e /etc/php.ini.rpmnew -a ! -e /etc/php.ini ]; then
        cp /etc/php.ini.rpmnew /etc/php.ini
    fi

     #RELEASEVER=$(rpm --eval %rhel)

    if [ $RELEASEVER -eq 6 ]; then
        yum --enablerepo=ius-archive -y install php56u-fpm php56u-cli pcre-devel php56u-mysql sox php56u-gd php56u-mbstring php56u-ioncube-loader php56u-pecl-redis php56u-soap
    else
        yum -y install https://rpms.remirepo.net/enterprise/remi-release-7.rpm
        yum -y install yum-utils
        #yum remove php*
        yum-config-manager --enable remi-php${phpver}
        yum -y install php-fpm php-cli pcre-devel php-mysqlnd sox php-gd php-mbstring php-pecl-redis php-soap php-xml php-zip
        #yum -y install php${phpver}-fpm php${phpver}-cli pcre-devel php${phpver}-mysqlnd sox php${phpver}-gd php${phpver}-mbstring php${phpver}-pecl-redis php${phpver}-soap php${phpver}-xml
        #yum -y install php74-fpm php74-cli pcre-devel php74-mysqlnd sox php74-gd php74-mbstring php74-ioncube-loader php74-pecl-redis php74-soap
    fi
    wget $downloadmirror/ioncube/ioncube_loader_lin_${ioncubever}.so -O /usr/lib64/php/modules/ioncube_loader_lin_${ioncubever}.so
    sed -i "s/short_open_tag = Off/short_open_tag = On\nzend_extension = \/usr\/lib64\/php\/modules\/ioncube_loader_lin_${ioncubever}.so/" /etc/php.ini 
    sed -i "s/memory_limit = 16M /memory_limit = 128M /" /etc/php.ini 
    sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 20M /" /etc/php.ini 
    sed -i "s/post_max_size = 8M/post_max_size = 20M/" /etc/php.ini
    sed -i '/^error_reporting/c error_reporting = E_ALL & ~E_DEPRECATED' /etc/php.ini
    sed -i "s/user = .*/user = asterisk/" /etc/php-fpm.d/www.conf
    sed -i "s/group = .*/group = asterisk/" /etc/php-fpm.d/www.conf
    if [ $RELEASEVER -eq 6 ]; then
        chkconfig php-fpm on
    else
        systemctl enable php-fpm
    fi
    echo -e "\e[32mPHP-Fpm Install OK!\e[m"
}

function fax_install(){
    echo -e "\e[32mStarting Install FAX\e[m"
  version=`cat /etc/issue|grep -o 'release [0-9]\+'`
    cd /usr/src
    #yum -y install hylafax
    yum -y install libtiff libtiff-devel

  bit=`getconf LONG_BIT`
  if [ $bit == 32 ]; then
    if [ "$version" == "release 6" ]; then
        if [ ! -e ./hylafax-client-6.0.6-1rhel6.i686.rpm ]; then
        wget ftp://ftp.hylafax.org/binary/linux/redhat/6.0.6/hylafax-client-6.0.6-1rhel6.i686.rpm
        fi
        if [ ! -e ./hylafax-server-6.0.6-1rhel6.i686.rpm ]; then
        wget ftp://ftp.hylafax.org/binary/linux/redhat/6.0.6/hylafax-server-6.0.6-1rhel6.i686.rpm
        fi
    else
      if [ ! -e ./hylafax-client-6.0.6-1rhel5.i386.rpm ]; then
        wget ftp://ftp.hylafax.org/binary/linux/redhat/6.0.6/hylafax-client-6.0.6-1rhel5.i386.rpm
      fi
      if [ ! -e ./hylafax-server-6.0.6-1rhel5.i386.rpm ]; then
        wget ftp://ftp.hylafax.org/binary/linux/redhat/6.0.6/hylafax-server-6.0.6-1rhel5.i386.rpm
      fi
    fi
    else
    if [ "$version" == "release 6" ]; then
      if [ ! -e ./hylafax-server-6.0.6-1rhel6.x86_64.rpm ]; then
        wget ftp://ftp.hylafax.org/binary/linux/redhat/6.0.6/hylafax-server-6.0.6-1rhel6.x86_64.rpm
      fi
      if [ ! -e ./hylafax-client-6.0.6-1rhel6.x86_64.rpm ]; then
        wget ftp://ftp.hylafax.org/binary/linux/redhat/6.0.6/hylafax-client-6.0.6-1rhel6.x86_64.rpm
      fi
    else
        if [ ! -e ./hylafax-server-6.0.6-1rhel5.x86_64.rpm ]; then
            wget ftp://ftp.hylafax.org/binary/linux/redhat/6.0.6/hylafax-server-6.0.6-1rhel5.x86_64.rpm
        fi
        if [ ! -e ./hylafax-client-6.0.6-1rhel5.x86_64.rpm ]; then
            wget ftp://ftp.hylafax.org/binary/linux/redhat/6.0.6/hylafax-client-6.0.6-1rhel5.x86_64.rpm
        fi
    fi
    fi

    rpm -ivh hylafax-*

    if [ ! -e ./iaxmodem-1.3.0.tar.gz ]; then
        wget http://sourceforge.net/projects/iaxmodem/files/latest/download?source=files -O iaxmodem-1.3.0.tar.gz
    fi
    tar zxf iaxmodem-1.3.0.tar.gz
    cd iaxmodem-1.3.0
    ./configure
    make
    cp ./iaxmodem /usr/sbin/
  chmod 777 /var/spool/hylafax/bin
  chmod 777 /var/spool/hylafax/etc/
  chmod 777 /var/spool/hylafax/docq/
  chmod 777 /var/spool/hylafax/doneq/
  mkdir /etc/iaxmodem/
  chown asterisk.asterisk /etc/iaxmodem/
  mkdir /var/log/iaxmodem/
  chown asterisk.asterisk /var/log/iaxmodem/
cat >  /var/spool/hylafax/etc/setup.cache << EOF
# Warning, this file was automatically generated by faxsetup
# on Thu Jun 28 13:48:41 CST 2012 for root
AWK='/usr/bin/gawk'
BASE64ENCODE='/usr/bin/uuencode -m ==== | /bin/grep -v ===='
BIN='/usr/bin'
CAT='/bin/cat'
CHGRP='/bin/chgrp'
CHMOD='/bin/chmod'
CHOWN='/bin/chown'
CP='/bin/cp'
DPSRIP='/var/spool/hylafax/bin/ps2fax'
ECHO='/bin/echo'
ENCODING='base64'
FAXQ_SERVER='yes'
FONTPATH='/usr/share/ghostscript/8.70/Resource/Init:/usr/share/ghostscript/8.70/lib:/usr/share/ghostscript/8.70/Resource/Font:/usr/share/ghostscript/fonts:/usr/share/fonts/default/ghostscript:/usr/share/fonts/default/Type1:/usr/share/fonts/default/amspsfnt/pfb:/usr/share/fonts/default/cmpsfont/pfb:/usr/share/fonts/japanese:/etc/ghostscript'
FUSER='/sbin/fuser'
GREP='/bin/grep'
GSRIP='/usr/bin/gs'
HFAXD_OLD_PROTOCOL='no'
HFAXD_SERVER='yes'
HFAXD_SNPP_SERVER='no'
IMPRIP=''
LIBDATA='/etc/hylafax'
LIBEXEC='/usr/sbin'
LN='/bin/ln'
MANDIR='/usr/share/man'
MIMENCODE='mimencode'
MKFIFO='/usr/bin/mkfifo'
MV='/bin/mv'
PATHEGETTY='/bin/egetty'
PATHGETTY='/sbin/mgetty'
PATH='/usr/sbin:/bin:/usr/bin:/etc:/usr/local/bin'
PATHVGETTY='/sbin/vgetty'
PSPACKAGE='gs'
QPENCODE='qp-encode'
RM='/bin/rm'
SBIN='/usr/sbin'
SCRIPT_SH='/bin/bash'
SED='/bin/sed'
SENDMAIL='/usr/sbin/sendmail'
SPOOL='/var/spool/hylafax'
SYSVINIT=''
TARGET='i686-pc-linux-gnu'
TIFF2PDF='/usr/bin/tiff2pdf'
TIFFBIN='/usr/bin'
TTYCMD='/usr/bin/tty'
UUCP_LOCKDIR='/var/lock'
UUCP_LOCKTYPE='ascii'
UUENCODE='/usr/bin/uuencode'
EOF

    echo -e "\e[32mFAX Install OK!\e[m"
}

function mpg123_install(){
    echo -e "\e[32mStarting Install MPG123\e[m"
    cd /usr/src
    if [ ! -e ./mpg123-$mpg123ver.tar.bz2 ]; then
        wget http://sourceforge.net/projects/mpg123/files/mpg123/$mpg123ver/mpg123-$mpg123ver.tar.bz2/download -O mpg123-$mpg123ver.tar.bz2
    fi
    tar jxf mpg123-$mpg123ver.tar.bz2
    cd mpg123-$mpg123ver
    ./configure
    make
    make install
    echo -e "\e[32mMPG123 Install OK!\e[m"

}

function dahdi_install() {
    echo -e "\e[32mStarting Install DAHDI\e[m"
    cd /usr/src
    if [ ! -e ./dahdi-linux-complete-$dahdiver.tar.gz ]; then
        wget $downloadmirror/dahdi-linux-complete-$dahdiver.tar.gz
        #if [ ! -e ./dahdi-linux-complete-$dahdiver.tar.gz ]; then
        #    wget http://downloads.asterisk.org/pub/telephony/dahdi-linux-complete/releases/dahdi-linux-complete-$dahdiver.tar.gz
        #fi
    fi
    tar zxf dahdi-linux-complete-$dahdiver.tar.gz
    if [ $? != 0 ]; then
        echo -e "fatal: dont have valid dahdi tar package\n"
        exit 1
    fi

    cd dahdi-linux-complete-$dahdiver
    make
    if [ $? != 0 ]; then
        yum -y update kernel
        echo -e "\e[32mplease reboot your server and run this script again\e[m\n"
        exit 1;
    fi
    make install
    make config
    /usr/sbin/dahdi_genconf
  echo "blacklist netjet" >> /etc/modprobe.d/dahdi.blacklist.conf
    /etc/init.d/dahdi start
    echo -e "\e[32mDAHDI Install OK!\e[m"
}

function nginx_install(){
    echo -e "\e[32mStarting install nginx\e[m"
    #service httpd stop
    #chkconfig httpd off
    cd /usr/src
    if [ ! -e ./nginx-$nginxver.tar.gz ]; then
        wget $downloadmirror/nginx-$nginxver.tar.gz
    fi
    tar zxf nginx-$nginxver.tar.gz
    if [ $? != 0 ]; then
        echo -e "fatal: dont have valid nginx tar package\n"
        exit 1
    fi

    if [ ! -e ./nginx-push-stream-module.tar.gz ]; then
        wget $downloadmirror/nginx-push-stream-module.tar.gz
    fi
    
    tar zxf nginx-push-stream-module.tar.gz
    if [ $? != 0 ]; then
        echo -e "fatal: dont have valid nginx push tar package\n"
        exit 1
    fi

    cd nginx-$nginxver
    ./configure --add-module=/usr/src/nginx-push-stream-module --with-http_ssl_module  --user=asterisk --group=asterisk
    make
    make install
     if [ $RELEASEVER -eq 6 ]; then
        wget $downloadmirror/nginx.zip
        unzip ./nginx.zip
        mv ./nginx /etc/init.d/
        chmod +x /etc/init.d/nginx
    fi
    echo -e "\e[32mNginx Install OK!\e[m"
}

function asterisk_install() {
    echo -e "\e[32mStarting Install Asterisk\e[m"
    useradd -u 500 -c "Asterisk PBX" -d /var/lib/asterisk asterisk
    #Define a user called asterisk.
    mkdir /var/run/asterisk /var/log/asterisk /var/spool/asterisk /var/lib/asterisk
    chown -R asterisk:asterisk /var/run/asterisk /var/log/asterisk /var/lib/php /var/lib/asterisk /var/spool/asterisk/
    #Change the owner of this file to asterisk.
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config 
    setenforce 0
    #shutdown selinux
    cd /usr/src
    if [ ! -e ./asterisk-$asteriskver.tar.gz ]; then
        #wget http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/asterisk-$asteriskver.tar.gz
        wget $downloadmirror/asterisk-$asteriskver.tar.gz
    fi
    tar zxf asterisk-$asteriskver.tar.gz
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
    sed -i "s/#AST_USER/AST_USER/" /etc/init.d/asterisk
    sed -i "s/#AST_GROUP/AST_GROUP/" /etc/init.d/asterisk

    sed -i 's/;enable=yes/enable=no/' /etc/asterisk/cdr.conf

    # set AMI user
cat > /etc/asterisk/manager.conf << EOF
[general]
enabled = yes
port = 5038
bindaddr = 0.0.0.0
displayconnects=no

[asterccuser]
secret = asterccsecret
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
read = system,call,agent
write = all
EOF
    if [ $RELEASEVER -eq 7 ]; then
        systemctl daemon-reload
        systemctl restart asterisk
        systemctl enable asterisk
    else
        /etc/init.d/asterisk restart
        chkconfig asterisk on
    fi
    echo -e "\e[32mAsterisk Install OK!\e[m"
}


function lame_install(){
    echo -e "\e[32mStarting Install Lame for mp3 monitor\e[m"
    cd /usr/src
    if [ ! -e ./lame-3.99.5.tar.gz ]; then
    wget --no-check-certificate http://sourceforge.net/projects/lame/files/lame/3.99/lame-3.99.5.tar.gz/download -O lame-3.99.5.tar.gz
    fi
    tar zxf lame-3.99.5.tar.gz
    if [ $? != 0 ]; then
        echo -e "\e[32mdont have valid lame tar package, you may lose the feature to check recordings on line\e[m\n"
        return 1
    fi

    cd lame-3.99.5
    ./configure && make && make install
    if [ $? != 0 ]; then
        echo -e "\e[32mfailed to install lame, you may lose the feature to check recordings on line\e[m\n"
        return 1
    fi
    ln -s /usr/local/bin/lame /usr/bin/
    echo -e "\e[32mLame install OK!\e[m"
    return 0;
}

function libpri_install() {
    echo -e "\e[32mStarting Install LibPRI\e[m"
    cd /usr/src
    if [ ! -e ./libpri-$libpriver.tar.gz ]; then
        #wget http://downloads.asterisk.org/pub/telephony/libpri/releases/libpri-$libpriver.tar.gz
        wget $downloadmirror/libpri-$libpriver.tar.gz
    fi
    tar zxf libpri-$libpriver.tar.gz
    if [ $? != 0 ]; then
        echo -e "fatal: dont have valid libpri tar package\n"
        exit 1
    fi

    cd libpri-$libpriver
    make
    make install
    echo -e "\e[32mLibPRI Install OK!\e[m"
}

function logrotate_install(){
cat > /etc/logrotate.d/astercc.logrotate << EOF
/opt/asterisk/scripts/astercc/*.log {
    daily
    rotate 10
    copytruncate
    delaycompress
    compress
    notifempty
    missingok
}
EOF
}

function nginx_conf_install(){
    mkdir /var/www/html/asterCC/http-log -p
cat >  /usr/local/nginx/conf/nginx.conf << EOF
#user  nobody;
worker_processes  1;
worker_rlimit_nofile 655350;

#error_log  logs/error.log;
#error_log  logs/error.log  notice;
#error_log  logs/error.log  info;

pid        /run/nginx.pid;


events {
    worker_connections  1024;
}


http {
    include       mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    #access_log  logs/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    #keepalive_timeout  0;
    keepalive_timeout  65;

    client_header_buffer_size 32k;
    large_client_header_buffers 4 32k;

    push_stream_store_messages on;
    push_stream_shared_memory_size  256M;
    push_stream_message_ttl  15m;

    #gzip  on;
    server
    {
        listen       80 default;
        client_max_body_size 20M;
        index index.html index.htm index.php;
        root  /var/www/html/asterCC/app/webroot;

        location / {
          index index.php;

          if (-f \$request_filename) {
            break;
          }
          if (!-f \$request_filename) {
            rewrite ^/(.+)\$ /index.php?url=\$1 last;
            break;
          }
  
            location  /agentindesks/pushagent {
                push_stream_publisher admin;
                push_stream_channels_path    \$arg_channel;
            }

            location ~ /agentindesks/agentpull/(.*) {
                push_stream_subscriber      long-polling;
                push_stream_channels_path    \$1;
                push_stream_message_template                 ~text~;
                push_stream_longpolling_connection_ttl        60s;	
            }

            location  /publicapi/pushagent {
                push_stream_publisher admin;
                push_stream_channels_path    \$arg_channel;
            }

            location ~ /publicapi/agentpull/(.*) {
                push_stream_subscriber      long-polling;
                push_stream_channels_path    \$1;
                push_stream_message_template         "{\"text\":\"~text~\",\"tag\":~tag~,\"time\":\"~time~\"}";
                push_stream_longpolling_connection_ttl        60s;
                push_stream_last_received_message_tag       \$arg_etag;
                push_stream_last_received_message_time      \$arg_since;
            }
            
            location  /systemevents/pushagent {
                push_stream_publisher admin;
                push_stream_channels_path    \$arg_channel;
            }

            location ~ /systemevents/agentpull/(.*) {
                push_stream_subscriber      long-polling;
                push_stream_channels_path    \$1;
                push_stream_message_template                 ~text~;
                push_stream_longpolling_connection_ttl        60s;
            }
        }

        location ~ /\.ht {
          deny all;
        }
        location ~ .*\.(php|php5)?\$
        {
          fastcgi_pass  127.0.0.1:9000;
          fastcgi_index index.php;
          include fastcgi_params;
          fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
          fastcgi_connect_timeout 60;
          fastcgi_send_timeout 180;
          fastcgi_read_timeout 180;
          fastcgi_buffer_size 128k;
          fastcgi_buffers 4 256k;
          fastcgi_busy_buffers_size 256k;
          fastcgi_temp_file_write_size 256k;
          fastcgi_intercept_errors on;
        }

        location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|wav)$
        {
          access_log   off;
          expires 15d;
        }

        location ~ .*\.(js|css)?$
        {
          expires 1d;
        }

        access_log /var/www/html/asterCC/http-log/access.log main;
    }
}
EOF
    #RELEASEVER=$(rpm --eval %rhel)

    if [ $RELEASEVER -eq 7 ]; then
cat > /lib/systemd/system/nginx.service << EOF
[Unit]
Description=The NGINX HTTP and reverse proxy server
After=syslog.target network-online.target remote-fs.target nss-lookup.target
Wants=network-online.target

[Service]
Type=forking
PIDFile=/run/nginx.pid
ExecStartPre=/usr/local/nginx/sbin/nginx -t -c /usr/local/nginx/conf/nginx.conf
ExecStart=/usr/local/nginx/sbin/nginx -c /usr/local/nginx/conf/nginx.conf
ExecReload=/usr/local/nginx/sbin/nginx -s reload
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        systemctl enable nginx 
        systemctl start nginx 
    else
        service nginx restart
    fi

echo -ne "
* soft nofile 655360
* hard nofile 655360
" >> /etc/security/limits.conf

echo "fs.file-max = 1572775" >> /etc/sysctl.conf
echo "net.ipv4.ip_local_port_range = 1024 65000" >> /etc/sysctl.conf
echo "net.ipv4.tcp_fin_timeout = 45" >> /etc/sysctl.conf
echo "vm.dirty_ratio=10" >> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_reuse = 1" >> /etc/sysctl.conf
echo "net.ipv4.tcp_tw_recycle = 1" >> /etc/sysctl.conf

sysctl -p
}

function astercc_install() {
    if [ $RELEASEVER -eq 7 ]; then
        systemctl restart asterisk
    else
        /etc/init.d/asterisk restart
    fi
    echo -e "\e[32mStarting Install AsterCC\e[m"
    cd /usr/src
    if [ ! -e ./astercc-$asterccver.tar.gz ]; then
        wget $downloadmirror/astercc-$asterccver.tar.gz -t 5
    fi
    tar zxf astercc-$asterccver.tar.gz
    if [ $? != 0 ]; then
        echo "dont have valid astercc tar package, try run this script again or download astercc-$asterccver.tar.gz to /usr/src manually then run this script again"
        exit 1
    fi

    cd astercc-$asterccver
    chmod +x install.sh
    . /tmp/.mysql_root_pw.$$

    ./install.sh -dbu=root -dbpw=$mysql_root_pw -amiu=$amiu -amipw=$amipw -allbydefault
    echo -e "\e[32mAsterCC Commercial Install OK!\e[m"
}

function set_ami(){
    while true;do
        echo -e "\e[32mplease give an AMI user\e[m";
        read amiu;
        if [ "X${amiu}" != "X" ]; then
            break;
        fi
    done

    while true;do
        echo -e "\e[32mplease give an AMI secret\e[m";
        read amipw;
        if [ "X${amipw}" != "X" ]; then
            break;
        fi
    done
cat > /etc/asterisk/manager.conf << EOF
[general]
enabled = yes
port = 5038
bindaddr = 0.0.0.0
displayconnects=no

[$amiu]
secret = $amipw
deny=0.0.0.0/0.0.0.0
permit=127.0.0.1/255.255.255.0
read = system,call,agent
write = all
EOF

    asterisk -rx "manager reload"

    echo amiu=$amiu >> /tmp/.mysql_root_pw.$$
    echo amipw=$amipw >> /tmp/.mysql_root_pw.$$
}

function get_mysql_passwd(){
    if [ $RELEASEVER -eq 7 ]; then
        systemctl start mariadb
    else
        service mysqld start
    fi
    while true;do
        echo -e "\e[32mplease enter your mysql root passwd\e[m";
        read mysql_passwd;
        # make sure it's not a empty passwd
        if [ "X${mysql_passwd}" != "X" ]; then
            mysqladmin -uroot -p$mysql_passwd password $mysql_passwd  >/dev/null 2>&1 # try empty passwd
            if [ $? == 0  ]; then
                mysql -uroot -p$mysql_passwd -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' IDENTIFIED by'$mysql_passwd';"
                mysql -uroot -pastercc -e "FLUSH PRIVILEGES"
                break;
            fi

            mysqladmin password "$mysql_passwd" 
            #mysql -uroot -p$mysql_passwd -e "SET PASSWORD FOR 'root'@'127.0.0.1' = PASSWORD('$mysql_passwd');"
            mysql -uroot -p$mysql_passwd -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' IDENTIFIED by'$mysql_passwd';"
            mysql -uroot -pastercc -e "FLUSH PRIVILEGES"
            if [ $? == 0  ]; then
                break;
            fi

            echo -e "\e[32minvalid password,please try again\e[m"
        fi
    done
cat > /etc/my.cnf << EOF
[mysql]
no-auto-rehash

[mysqld]
datadir=/var/lib/mysql
socket=/var/lib/mysql/mysql.sock
user=mysql
# Default to using old password format for compatibility with mysql 3.x
# clients (those using the mysqlclient10 compatibility package).
#old_passwords=1

# Disabling symbolic-links is recommended to prevent assorted security risks;
# to do so, uncomment this line:
# symbolic-links=0
skip-name-resolve
skip-external-locking
### table_open_cache = 1024

open_files_limit = 10240
back_log = 600

## MyISAM Engine
key_buffer_size = 384M
myisam_sort_buffer_size         = 128M  #index buffer size for creating/altering indexes
myisam_max_sort_file_size       = 256M  #max file size for tmp table when creating/alering indexes
myisam_repair_threads           = 4     #thread quantity when running repairs
myisam_recover                  = BACKUP        #repair mode, recommend BACKUP

## Connections
max_connections = 4096
max_connect_errors              = 8192  #default: 10
concurrent_insert               = 2     #default: 1, 2: enable insert for all instances
connect_timeout                 = 30    #default -5.1.22: 5, +5.1.22: 10
max_allowed_packet              = 64M   #max size of incoming data to allow

## Thread settings
### thread_concurrency = 16
#
###thread_cache_size               = 300 #recommend 5% of max_connections
# 1G memory: 8
# 2G memory: 16
# 3G memory: 32
# 4G memory: +

## Per-Thread Buffers * (max_connections) = total per-thread mem usage
thread_stack                    = 256K    #default: 32bit: 192K, 64bit: 256K
sort_buffer_size                = 512K    #default: 2M, larger may cause perf issues
read_buffer_size                = 1M    #default: 128K, change in increments of 4K
read_rnd_buffer_size            = 512K    #default: 256K
join_buffer_size                = 512K    #default: 128K
binlog_cache_size               = 64K     #default: 32K, size of buffer to hold TX queries


query_cache_size = 64M
query_cache_limit = 4M

max_heap_table_size = 256M
bulk_insert_buffer_size = 64M
tmp_table_size = 256M

wait_timeout = 180
### long_query_time=1
### log-slow-queries=/var/log/mysqld_slow.log

innodb_file_per_table = 1
innodb_table_locks = 0
innodb_log_buffer_size          = 128M  #global buffer
innodb_lock_wait_timeout        = 60
innodb_thread_concurrency       = ##CPUCORE##    #recommend 2x core quantity
innodb_commit_concurrency       = ##CPUCORE##    #recommend 4x num disks
skip-innodb-doublewrite
innodb_flush_log_at_trx_commit  = 2
expire_logs_days = 5
### innodb_buffer_pool_size = 1024M         #recommend 70-80% of the memory if it's dedicated for mysql
### innodb_stats_on_metadata = 0
sql_mode=NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION
#STRICT_TRANS_TABLES

[mysqld_safe]
log-error=/var/log/mysqld.log
pid-file=/var/run/mysqld/mysqld.pid
EOF
    echo mysql_root_pw=$mysql_passwd > /tmp/.mysql_root_pw.$$
    if [ $RELEASEVER -eq 7 ]; then
        systemctl restart mariadb
    else
        service mysqld restart
    fi
}

function iptables_config(){
    echo "start setting firewall"
    if [ $RELEASEVER -eq 7 ]; then
        firewall-cmd --zone=public --add-port=80/tcp --permanent
        firewall-cmd --zone=public --add-port=5060/udp --permanent
        firewall-cmd --zone=public --add-port=5036/udp --permanent
        firewall-cmd --zone=public --add-port=4569/udp --permanent
        firewall-cmd --zone=public --add-port=10000-20000/udp --permanent
        if [ $? == 0 ];then
            systemctl restart firewalld
        else
            echo -e "\033[33mFirewallD may not running, ignore setting  \033[0m"
        fi
    else
        iptables -I INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p udp -m udp --dport 5060 -j ACCEPT
        iptables -A INPUT -p udp -m udp --dport 5036 -j ACCEPT
        iptables -A INPUT -p udp -m udp --dport 4569 -j ACCEPT
        iptables -A INPUT -p udp -m udp --dport 10000:20000 -j ACCEPT
        iptables-save > /etc/sysconfig/iptables
        service iptables restart
    fi
}

function run() {
    yum -y install wget
    downloadmirror=http://download1.astercc.org

    echo "please select the mirror you want to download from:"
    echo "1: German Server"
    echo "2: U.S. Server"
    echo "3: China Server (China Mobile)"
    read downloadserver;
    RELEASEVER=$(rpm --eval %rhel)

    if [ "$downloadserver" == "1"  ]; then
        downloadmirror=http://download1.astercc.org;
    fi
    if [ "$downloadserver" == "2"  ]; then
        downloadmirror=http://download2.astercc.org;
    fi
    if [ "$downloadserver" == "3"  ]; then
        downloadmirror=http://download3.astercc.org;
    fi

    if [ $RELEASEVER -eq 7 ]; then
        wget $downloadmirror/asterccver1_centos7_php7 -t 5
        if [ ! -e ./asterccver1_centos7_php7 ]; then
            echo "failed to get version infromation,please try again"
            exit 1;
        fi
        . ./asterccver1_centos7_php7
        /bin/rm -rf ./asterccver1_centos7_php7
    else
        wget $downloadmirror/asterccver1 -t 5
        if [ ! -e ./asterccver1 ]; then
            echo "failed to get version infromation,please try again"
            exit 1;
        fi
        . ./asterccver1
        /bin/rm -rf ./asterccver1
    fi
    newRepo_install
    yum_install
    php_install
    dahdi_install
    libpri_install
    asterisk_install
    lame_install
    mpg123_install
    nginx_install
    get_mysql_passwd
    set_ami
    /etc/init.d/asterisk restart
    astercc_install
    nginx_conf_install
    logrotate_install
    iptables_config
    echo "asterisk ALL = NOPASSWD :/etc/init.d/asterisk" >> /etc/sudoers
    echo "asterisk ALL = NOPASSWD: /usr/bin/reboot" >> /etc/sudoers
    echo "asterisk ALL = NOPASSWD: /sbin/shutdown" >> /etc/sudoers
    /bin/rm -rf /tmp/.mysql_root_pw.$$
    ln -s /var/lib/asterisk/moh /var/lib/asterisk/mohmp3
    if [ $RELEASEVER -eq 7 ]; then
        systemctl start php-fpm
        systemctl restart firewalld
        systemctl enable redis
        systemctl start redis
    else
        /etc/init.d/php-fpm start
        /etc/init.d/iptables restart
        /etc/init.d/redis start
        chkconfig redis on
    fi
    echo -e "\e[32masterCC Commercial installation finish!\e[m";
}

run
