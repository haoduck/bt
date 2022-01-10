#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH
LANG=en_US.UTF-8

if [ $(whoami) != "root" ];then
	echo "Please use the [root] user to execute the aapanel installation script!"
	exit 1;
fi

is64bit=$(getconf LONG_BIT)
if [ "${is64bit}" != '64' ];then
	Red_Error "Sorry, aaPanel does not support 32-bit systems";
fi

Centos6Check=$(cat /etc/redhat-release | grep ' 6.' | grep -iE 'centos|Red Hat')
if [ "${Centos6Check}" ];then
	echo "Sorry, Centos6 does not support installing aaPanel"
	exit 1
fi 

UbuntuCheck=$(cat /etc/issue|grep Ubuntu|awk '{print $2}'|cut -f 1 -d '.')
if [ "${UbuntuCheck}" -lt "16" ];then
	echo "Ubuntu ${UbuntuCheck} is not supported to the aaPanel, it is recommended to replace the Ubuntu18/20 to install"
	exit 1
fi

cd ~
setup_path="/www"
SET_SSL=false
python_bin=$setup_path/server/panel/pyenv/bin/python
cpu_cpunt=$(cat /proc/cpuinfo|grep processor|wc -l)
if [ "$1" ];then
	IDC_CODE=$1
fi

GetSysInfo(){
	if [ -s "/etc/redhat-release" ];then
		SYS_VERSION=$(cat /etc/redhat-release)
	elif [ -s "/etc/issue" ]; then
		SYS_VERSION=$(cat /etc/issue)
	fi
	SYS_INFO=$(uname -a)
	SYS_BIT=$(getconf LONG_BIT)
	MEM_TOTAL=$(free -m|grep Mem|awk '{print $2}')
	CPU_INFO=$(getconf _NPROCESSORS_ONLN)

	echo -e ${SYS_VERSION}
	echo -e Bit:${SYS_BIT} Mem:${MEM_TOTAL}M Core:${CPU_INFO}
	echo -e ${SYS_INFO}
	echo -e "Please screenshot the above error message and post to the forum forum.aapanel.com for help"
}
Red_Error(){
	echo '=================================================';
	printf '\033[1;31;40m%b\033[0m\n' "$@";
	GetSysInfo
	exit 1;
}
Lock_Clear(){
	if [ -f "/etc/bt_crack.pl" ];then
		chattr -R -ia /www
		chattr -ia /etc/init.d/bt
		\cp -rpa /www/backup/panel/vhost/* /www/server/panel/vhost/
		mv /www/server/panel/BTPanel/__init__.bak /www/server/panel/BTPanel/__init__.py
		rm -f /etc/bt_crack.pl
	fi
}
Install_Check(){
	if [ "${INSTALL_FORCE}" ];then
		return
	fi
	echo -e "----------------------------------------------------"
	echo -e "Web service is alreday installed,installing aaPanel may affect existing sites."
	echo -e "----------------------------------------------------"
	echo -e "Enter [yes] to force installation"
	read -p "Enter yes to force installation: " yes;
	if [ "$yes" != "yes" ];then
		echo -e "------------"
		echo "Installation canceled"
		exit;
	fi
	INSTALL_FORCE="true"		 
}
System_Check(){
	MYSQLD_CHECK=$(ps -ef |grep mysqld|grep -v grep|grep -v /www/server/mysql)
	PHP_CHECK=$(ps -ef|grep php-fpm|grep master|grep -v /www/server/php)
	NGINX_CHECK=$(ps -ef|grep nginx|grep master|grep -v /www/server/nginx)
	HTTPD_CHECK=$(ps -ef |grep -E 'httpd|apache'|grep -v /www/server/apache|grep -v grep)
	if [ "${PHP_CHECK}" ] || [ "${MYSQLD_CHECK}" ] || [ "${NGINX_CHECK}" ] || [ "${HTTPD_CHECK}" ];then
		Install_Check
	fi
}
Set_Ssl(){
        echo -e ""
        echo -e "----------------------------------------------------------------------"
        echo -e "If you choose to enable SSL (self-signed certificate), you will use https access panel after installation."
        echo -e "After logging in, you can go to the panel settings and change to Let's Encrypt certificate."
        echo -e "----------------------------------------------------------------------"
        echo -e ""
        read -p "Do you need to enable the panel SSl ? (yes/n): " yes;
        if [ "$yes" == "yes" ];then
                SET_SSL=true
        fi
        if [ "$yes" != "yes" ] && [ $yes != "n" ];then
                Set_Ssl
        fi
}
Get_Pack_Manager(){
	if [ -f "/usr/bin/yum" ] && [ -d "/etc/yum.repos.d" ]; then
		PM="yum"
	elif [ -f "/usr/bin/apt-get" ] && [ -f "/usr/bin/dpkg" ]; then
		PM="apt-get"		
	fi
}

Auto_Swap()
{
	swap=$(free |grep Swap|awk '{print $2}')
	if [ "${swap}" -gt 1 ];then
		echo "Swap total sizse: $swap";
		return;
	fi
	if [ ! -d /www ];then
		mkdir /www
	fi
	swapFile="/www/swap"
	dd if=/dev/zero of=$swapFile bs=1M count=1025
	mkswap -f $swapFile
	swapon $swapFile
	echo "$swapFile    swap    swap    defaults    0 0" >> /etc/fstab
	swap=`free |grep Swap|awk '{print $2}'`
	if [ $swap -gt 1 ];then
		echo "Swap total sizse: $swap";
		return;
	fi
	
	sed -i "/\/www\/swap/d" /etc/fstab
	rm -f $swapFile
}
Service_Add(){
	if [ "${PM}" == "yum" ] || [ "${PM}" == "dnf" ]; then
		chkconfig --add bt
		chkconfig --level 2345 bt on
	elif [ "${PM}" == "apt-get" ]; then
		update-rc.d bt defaults
	fi 
}

get_node_url(){
	if [ ! -f /bin/curl ];then
		if [ "${PM}" = "yum" ]; then
			yum install curl -y
		elif [ "${PM}" = "apt-get" ]; then
			apt-get install curl -y
		fi
	fi
	
 	echo '---------------------------------------------';
	echo "Selected download node...";
	nodes=(http://node.aapanel.com);
	tmp_file1=/dev/shm/net_test1.pl
	tmp_file2=/dev/shm/net_test2.pl
						  
	[ -f "${tmp_file1}" ] && rm -f ${tmp_file1}
   
						  
	[ -f "${tmp_file2}" ] && rm -f ${tmp_file2}
   
	touch $tmp_file1
	touch $tmp_file2
	for node in ${nodes[@]};
	do
		NODE_CHECK=$(curl --connect-timeout 3 -m 3 2>/dev/null -w "%{http_code} %{time_total}" ${node}/net_test|xargs)
		RES=$(echo ${NODE_CHECK}|awk '{print $1}')
		NODE_STATUS=$(echo ${NODE_CHECK}|awk '{print $2}')
		TIME_TOTAL=$(echo ${NODE_CHECK}|awk '{print $3 * 1000 - 500 }'|cut -d '.' -f 1)
		if [ "${NODE_STATUS}" == "200" ];then
			if [ $TIME_TOTAL -lt 100 ];then
				if [ $RES -ge 1500 ];then
					echo "$RES $node" >> $tmp_file1
				fi
			else
				if [ $RES -ge 1500 ];then
					echo "$TIME_TOTAL $node" >> $tmp_file2
				fi
			fi

			i=$(($i+1))
			if [ $TIME_TOTAL -lt 100 ];then
				if [ $RES -ge 3000 ];then
					break;
				fi
			fi	
   
		fi
	done

	NODE_URL=$(cat $tmp_file1|sort -r -g -t " " -k 1|head -n 1|awk '{print $2}')
	if [ -z "$NODE_URL" ];then
		NODE_URL=$(cat $tmp_file2|sort -g -t " " -k 1|head -n 1|awk '{print $2}')
		if [ -z "$NODE_URL" ];then
			NODE_URL='http://node.aapanel.com';
		fi
	fi

	rm -f $tmp_file1
	rm -f $tmp_file2
	download_Url=$NODE_URL
	echo "Download node: $download_Url";
	echo '---------------------------------------------';
}
Remove_Package(){
	local PackageNmae=$1
	if [ "${PM}" == "yum" ];then
		isPackage=$(rpm -q ${PackageNmae}|grep "not installed")
		if [ -z "${isPackage}" ];then
			yum remove ${PackageNmae} -y
		fi 
	elif [ "${PM}" == "apt-get" ];then
		isPackage=$(dpkg -l|grep ${PackageNmae})
		if [ "${PackageNmae}" ];then
			apt-get remove ${PackageNmae} -y
		fi
	fi
}
Install_RPM_Pack(){
	yumPath=/etc/yum.conf
	Centos8Check=$(cat /etc/redhat-release | grep ' 8.' | grep -iE 'centos|Red Hat')
	isExc=$(cat $yumPath|grep httpd)
	if [ "$isExc" = "" ];then
		echo "exclude=httpd nginx php mysql mairadb python-psutil python2-psutil" >> $yumPath
	fi

	#yumBaseUrl=$(cat /etc/yum.repos.d/CentOS-Base.repo|grep baseurl=http|cut -d '=' -f 2|cut -d '$' -f 1|head -n 1)
	#[ "${yumBaseUrl}" ] && checkYumRepo=$(curl --connect-timeout 5 --head -s -o /dev/null -w %{http_code} ${yumBaseUrl})	
	#if [ "${checkYumRepo}" != "200" ];then
	#	curl -Ss --connect-timeout 3 -m 60 http://node.aapanel.com/install/yumRepo_select.sh|bash
	#fi
	
	#尝试同步时间(从bt.cn)
# 	echo 'Synchronizing system time...'
# 	getBtTime=$(curl -sS --connect-timeout 3 -m 60 http://www.bt.cn/api/index/get_time)
# 	if [ "${getBtTime}" ];then	
#     		date -s "$(date -d @$getBtTime +"%Y-%m-%d %H:%M:%S")"
# 	fi

	#if [ -z "${Centos8Check}" ]; then
	#	yum install ntp -y
	#	rm -rf /etc/localtime
	#	ln -s /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

		#尝试同步国际时间(从ntp服务器)
	#	ntpdate 0.asia.pool.ntp.org
	#	setenforce 0
	#fi

	startTime=`date +%s`

	sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
	#yum remove -y python-requests python3-requests python-greenlet python3-greenlet
	yumPacks="libcurl-devel wget tar gcc make zip unzip openssl openssl-devel gcc libxml2 libxml2-devel libxslt* zlib zlib-devel libjpeg-devel libpng-devel libwebp libwebp-devel freetype freetype-devel lsof pcre pcre-devel vixie-cron crontabs icu libicu-devel c-ares libffi-devel bzip2-devel ncurses-devel sqlite-devel readline-devel tk-devel gdbm-devel db4-devel libpcap-devel xz-devel"
	yum install -y ${yumPacks}

	for yumPack in ${yumPacks}
	do
		rpmPack=$(rpm -q ${yumPack})
		packCheck=$(echo ${rpmPack}|grep not)
		if [ "${packCheck}" ]; then
			yum install ${yumPack} -y
		fi
	done
	if [ -f "/usr/bin/dnf" ]; then
		dnf install -y redhat-rpm-config
	fi

	ALI_OS=$(cat /etc/redhat-release |grep "Alibaba Cloud Linux release 3")
	if [ -z "${ALI_OS}" ];then 
		yum install epel-release -y
    fi
}
Install_Deb_Pack(){
	ln -sf bash /bin/sh
	apt-get update -y
	apt-get install ruby -y
	apt-get install lsb-release -y
	#apt-get install ntp ntpdate -y
	#/etc/init.d/ntp stop
	#update-rc.d ntp remove
	#cat >>~/.profile<<EOF
	#TZ='Asia/Shanghai'; export TZ
	#EOF
	#rm -rf /etc/localtime
	#cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
	#echo 'Synchronizing system time...'
	#ntpdate 0.asia.pool.ntp.org
	#apt-get upgrade -y
	debPacks="wget curl libcurl4-openssl-dev gcc make zip unzip tar openssl libssl-dev gcc libxml2 libxml2-dev zlib1g zlib1g-dev libjpeg-dev libpng-dev lsof libpcre3 libpcre3-dev cron net-tools swig build-essential libffi-dev libbz2-dev libncurses-dev libsqlite3-dev libreadline-dev tk-dev libgdbm-dev libdb-dev libdb++-dev libpcap-dev xz-utils git";
	apt-get install -y $debPacks --force-yes

	for debPack in ${debPacks}
	do
		packCheck=$(dpkg -l ${debPack})
		if [ "$?" -ne "0" ] ;then
			apt-get install -y debPack
		fi
	done
	if [ ! -d '/etc/letsencrypt' ];then
		mkdir -p /etc/letsencryp
		mkdir -p /var/spool/cron
		if [ ! -f '/var/spool/cron/crontabs/root' ];then
			echo '' > /var/spool/cron/crontabs/root
			chmod 600 /var/spool/cron/crontabs/root
		fi	
	fi
}
Get_Versions(){
	redhat_version_file="/etc/redhat-release"
	deb_version_file="/etc/issue"
	if [ -f $redhat_version_file ];then
		os_type='el'
		is_aliyunos=$(cat $redhat_version_file|grep Aliyun)
		if [ "$is_aliyunos" != "" ];then
			return
		fi
		os_version=$(cat $redhat_version_file|grep CentOS|grep -Eo '([0-9]+\.)+[0-9]+'|grep -Eo '^[0-9]')
		if [ "${os_version}" = "5" ];then
			os_version=""
		fi
	else
		os_type='ubuntu'
		os_version=$(cat $deb_version_file|grep Ubuntu|grep -Eo '([0-9]+\.)+[0-9]+'|grep -Eo '^[0-9]+')
		if [ "${os_version}" = "" ];then
			os_type='debian'
			os_version=$(cat $deb_version_file|grep Debian|grep -Eo '([0-9]+\.)+[0-9]+'|grep -Eo '[0-9]+')
			if [ "${os_version}" = "" ];then
				os_version=$(cat $deb_version_file|grep Debian|grep -Eo '[0-9]+')
			fi
			if [ "${os_version}" = "8" ];then
				os_version=""
			fi
			if [ "${is64bit}" = '32' ];then
				os_version=""
			fi
		else
			if [ "$os_version" = "14" ];then
				os_version=""
			fi
			if [ "$os_version" = "12" ];then
				os_version=""
			fi
			if [ "$os_version" = "19" ];then
				os_version=""
			fi
		fi
	fi
}

Install_Python_Lib(){
	#curl -Ss --connect-timeout 3 -m 60 $download_Url/install/pip_select.sh|bash
	pyenv_path="/www/server/panel"
	if [ -f $pyenv_path/pyenv/bin/python ];then
		is_ssl=$($python_bin -c "import ssl" 2>&1|grep cannot)
		$pyenv_path/pyenv/bin/python3.7 -V
		if [ $? -eq 0 ] && [ -z "${is_ssl}" ];then
			chmod -R 700 $pyenv_path/pyenv/bin
			$pyenv_path/pyenv/bin/pip install cachelib
			is_package=$($python_bin -m psutil 2>&1|grep package)
			if [ "$is_package" = "" ];then
				wget -O $pyenv_path/pyenv/pip.txt $download_Url/install/pyenv/pip.txt -T 5
				$pyenv_path/pyenv/bin/pip install -U pip
				$pyenv_path/pyenv/bin/pip install -U setuptools
				$pyenv_path/pyenv/bin/pip install -r $pyenv_path/pyenv/pip.txt
				$pyenv_path/pyenv/bin/pip install cachelib
			fi
			source $pyenv_path/pyenv/bin/activate
			return
		else
			rm -rf $pyenv_path/pyenv
		fi
	fi
	py_version="3.7.8"
	mkdir -p $pyenv_path
	echo "True" > /www/disk.pl
	if [ ! -w /www/disk.pl ];then
		Red_Error "ERROR: Install python env fielded." "ERROR: path [www] cannot be written, please check the directory/user/disk permissions!"
    fi
	os_type='el'
	os_version='7'
	is_export_openssl=0
	Get_Versions
	echo "OS: $os_type - $os_version"
	is_aarch64=$(uname -a|grep aarch64)
	if [ "$is_aarch64" != "" ];then
		is64bit="aarch64"
	fi
	if [ -f "/www/server/panel/pymake.pl" ];then
		os_version=""
		rm -f /www/server/panel/pymake.pl
	fi
	if [ "${os_version}" != "" ];then
		pyenv_file="/www/pyenv.tar.gz"
		wget -O $pyenv_file $download_Url/install/pyenv/pyenv-${os_type}${os_version}-x${is64bit}.tar.gz -T 10
		tmp_size=$(du -b $pyenv_file|awk '{print $1}')
		if [ $tmp_size -lt 703460 ];then
			rm -f $pyenv_file
			echo "ERROR: Download python env fielded."
		else
			echo "Install python env..."
			tar zxvf $pyenv_file -C $pyenv_path/ > /dev/null
			chmod -R 700 $pyenv_path/pyenv/bin
			if [ ! -f $pyenv_path/pyenv/bin/python ];then
				rm -f $pyenv_file
				Red_Error "ERROR: Install python env fielded. Please try to reinstall"
			fi
			$pyenv_path/pyenv/bin/python3.7 -V
			if [ $? -eq 0 ];then
				rm -f $pyenv_file
				ln -sf $pyenv_path/pyenv/bin/pip3.7 /usr/bin/btpip
				ln -sf $pyenv_path/pyenv/bin/python3.7 /usr/bin/btpython
				source $pyenv_path/pyenv/bin/activate
				return
			else
				rm -f $pyenv_file
				rm -rf $pyenv_path/pyenv
			fi
		fi
	fi

	cd /www
	python_src='/www/python_src.tar.xz'
	python_src_path="/www/Python-${py_version}"
	wget -O $python_src $download_Url/src/Python-${py_version}.tar.xz -T 5
	tmp_size=$(du -b $python_src|awk '{print $1}')
	if [ $tmp_size -lt 10703460 ];then
		rm -f $python_src
		Red_Error "ERROR: Download python source code fielded. Please try to reinstall"
	fi
	tar xvf $python_src
	rm -f $python_src
	cd $python_src_path
	./configure --prefix=$pyenv_path/pyenv
	make -j$cpu_cpunt
	make install
	if [ ! -f $pyenv_path/pyenv/bin/python3.7 ];then
		rm -rf $python_src_path
		Red_Error "ERROR: Make python env fielded. Please try to reinstall"
	fi
	cd ~
	rm -rf $python_src_path
	wget -O $pyenv_path/pyenv/bin/activate $download_Url/install/pyenv/activate.panel -T 5
	wget -O $pyenv_path/pyenv/pip.txt $download_Url/install/pyenv/pip-3.7.8.txt -T 5
	ln -sf $pyenv_path/pyenv/bin/pip3.7 $pyenv_path/pyenv/bin/pip
	ln -sf $pyenv_path/pyenv/bin/python3.7 $pyenv_path/pyenv/bin/python
	ln -sf $pyenv_path/pyenv/bin/pip3.7 /usr/bin/btpip
	ln -sf $pyenv_path/pyenv/bin/python3.7 /usr/bin/btpython
	chmod -R 700 $pyenv_path/pyenv/bin
	$pyenv_path/pyenv/bin/pip install -U pip
	$pyenv_path/pyenv/bin/pip install -U setuptools
	$pyenv_path/pyenv/bin/pip install -U wheel==0.34.2 
	$pyenv_path/pyenv/bin/pip install -r $pyenv_path/pyenv/pip.txt
	$pyenv_path/pyenv/bin/pip install -U cachelib
	
	source $pyenv_path/pyenv/bin/activate
	
	is_gevent=$($python_bin -m gevent 2>&1|grep -oE package)
	is_psutil=$($python_bin -m psutil 2>&1|grep -oE package)
	if [ "${is_gevent}" != "${is_psutil}" ];then
		Red_Error "ERROR: psutil/gevent install failed!"
	fi
}
Install_Bt(){
	panelPort="8888"
	if [ -f ${setup_path}/server/panel/data/port.pl ];then
		panelPort=$(cat ${setup_path}/server/panel/data/port.pl)
	fi
	mkdir -p ${setup_path}/server/panel/logs
	mkdir -p ${setup_path}/server/panel/vhost/apache
	mkdir -p ${setup_path}/server/panel/vhost/nginx
	mkdir -p ${setup_path}/server/panel/vhost/rewrite
	mkdir -p ${setup_path}/server/panel/install
	mkdir -p /www/server
	mkdir -p /www/wwwroot
	mkdir -p /www/wwwlogs
	mkdir -p /www/backup/database
	mkdir -p /www/backup/site


	if [ -f "/etc/init.d/bt" ]; then
		/etc/init.d/bt stop
		sleep 1
	fi

	wget -O panel.zip ${download_Url}/install/src/panel6_en.zip -T 10
	wget -O /etc/init.d/bt ${download_Url}/install/src/bt6_en.init -T 10
	wget -O /www/server/panel/install/public.sh ${download_Url}/install/public.sh -T 10

	if [ -f "${setup_path}/server/panel/data/default.db" ];then
		if [ -d "/${setup_path}/server/panel/old_data" ];then
			rm -rf ${setup_path}/server/panel/old_data
		fi
		mkdir -p ${setup_path}/server/panel/old_data
		d_format=$(date +"%Y%m%d_%H%M%S")
		\cp -arf ${setup_path}/server/panel/data/default.db ${setup_path}/server/panel/data/default_backup_${d_format}.db
		mv -f ${setup_path}/server/panel/data/default.db ${setup_path}/server/panel/old_data/default.db
		mv -f ${setup_path}/server/panel/data/system.db ${setup_path}/server/panel/old_data/system.db
		mv -f ${setup_path}/server/panel/data/port.pl ${setup_path}/server/panel/old_data/port.pl
		mv -f ${setup_path}/server/panel/data/admin_path.pl ${setup_path}/server/panel/old_data/admin_path.pl
	fi

	if [ ! -f "/usr/bin/unzip" ]; then
		if [ "${PM}" = "yum" ]; then
			yum install unzip -y
		elif [ "${PM}" = "apt-get" ]; then
			apt-get update
			apt-get install unzip -y
		fi
    fi
	unzip -o panel.zip -d ${setup_path}/server/ > /dev/null

	if [ -d "${setup_path}/server/panel/old_data" ];then
		mv -f ${setup_path}/server/panel/old_data/default.db ${setup_path}/server/panel/data/default.db
		mv -f ${setup_path}/server/panel/old_data/system.db ${setup_path}/server/panel/data/system.db
		mv -f ${setup_path}/server/panel/old_data/port.pl ${setup_path}/server/panel/data/port.pl
		mv -f ${setup_path}/server/panel/old_data/admin_path.pl ${setup_path}/server/panel/data/admin_path.pl
		if [ -d "/${setup_path}/server/panel/old_data" ];then
			rm -rf ${setup_path}/server/panel/old_data
		fi
	fi


	if [ ! -f ${setup_path}/server/panel/tools.py ] || [ ! -f ${setup_path}/server/panel/BT-Panel ];then
		ls -lh panel.zip
		Red_Error "ERROR: Failed to download, please try install again!"
	fi

	rm -f panel.zip
	rm -f ${setup_path}/server/panel/class/*.pyc
	rm -f ${setup_path}/server/panel/*.pyc

	chmod +x /etc/init.d/bt
	chmod -R 600 ${setup_path}/server/panel
	chmod -R +x ${setup_path}/server/panel/script
	ln -sf /etc/init.d/bt /usr/bin/bt
	echo "${panelPort}" > ${setup_path}/server/panel/data/port.pl
	wget -O /etc/init.d/bt ${download_Url}/install/src/bt6_en.init -T 10
	wget -O /www/server/panel/init.sh ${download_Url}/install/src/bt6_en.init -T 10
	wget -O /www/server/panel/data/softList.conf ${download_Url}/install/conf/softList.conf
}
Other_Openssl(){
	openssl_version=$(openssl version|grep -Eo '[0-9]\.[0-9]\.[0-9]')
	if [ "$openssl_version" = '1.0.1' ] || [ "$openssl_version" = '1.0.0' ];then	
		opensslVersion="1.0.2r"
		if [ ! -f "/usr/local/openssl/lib/libssl.so" ];then
			cd /www
			openssl_src_file=/www/openssl.tar.gz
			wget -O $openssl_src_file ${download_Url}/src/openssl-${opensslVersion}.tar.gz
			tmp_size=$(du -b $openssl_src_file|awk '{print $1}')
			if [ $tmp_size -lt 703460 ];then
				rm -f $openssl_src_file
				Red_Error "ERROR: Download openssl-1.0.2 source code fielded."
			fi
			tar -zxf $openssl_src_file
			rm -f $openssl_src_file
			cd openssl-${opensslVersion}
			#zlib-dynamic shared
			./config --openssldir=/usr/local/openssl zlib-dynamic shared
			make -j${cpuCore} 
			make install
			echo  "/usr/local/openssl/lib" > /etc/ld.so.conf.d/zopenssl.conf
			ldconfig
			cd ..
			rm -rf openssl-${opensslVersion}
			is_export_openssl=1
			cd ~
		fi
	fi
}

Insatll_Libressl(){
	openssl_version=$(openssl version|grep -Eo '[0-9]\.[0-9]\.[0-9]')
	if [ "$openssl_version" = '1.0.1' ] || [ "$openssl_version" = '1.0.0' ];then	
		opensslVersion="3.0.2"
		cd /www
		openssl_src_file=/www/openssl.tar.gz
		wget -O $openssl_src_file ${download_Url}/install/pyenv/libressl-${opensslVersion}.tar.gz
		tmp_size=$(du -b $openssl_src_file|awk '{print $1}')
		if [ $tmp_size -lt 703460 ];then
			rm -f $openssl_src_file
			Red_Error "ERROR: Download libressl-$opensslVersion source code fielded."
		fi
		tar -zxf $openssl_src_file
		rm -f $openssl_src_file
		cd libressl-${opensslVersion}
		./config –prefix=/usr/local/lib
		make -j${cpuCore}
		make install
		ldconfig
		ldconfig -v
		cd ..
		rm -rf libressl-${opensslVersion}
		is_export_openssl=1
		cd ~
	fi
}

Centos6_Openssl(){
	if [ "$os_type" != 'el' ];then
		return
	fi
	if [ "$os_version" != '6' ];then
		return
	fi
	echo 'Centos6 install openssl-1.0.2...'
	openssl_rpm_file="/www/openssl.rpm"
	wget -O $openssl_rpm_file $download_Url/rpm/centos6/${is64bit}/bt-openssl102.rpm -T 10
	tmp_size=$(du -b $openssl_rpm_file|awk '{print $1}')
	if [ $tmp_size -lt 102400 ];then
		rm -f $openssl_rpm_file
		Red_Error "ERROR: Download python env fielded."
	fi
	rpm -ivh $openssl_rpm_file
	rm -f $openssl_rpm_file
	is_export_openssl=1
}

Get_Versions(){
	redhat_version_file="/etc/redhat-release"
	deb_version_file="/etc/issue"
	if [ -f $redhat_version_file ];then
		os_type='el'
		is_aliyunos=$(cat $redhat_version_file|grep Aliyun)
		if [ "$is_aliyunos" != "" ];then
			return
		fi
		os_version=$(cat $redhat_version_file|grep CentOS|grep -Eo '([0-9]+\.)+[0-9]+'|grep -Eo '^[0-9]')
		if [ "${os_version}" = "5" ];then
			os_version=""
		fi
	else
		os_type='ubuntu'
		os_version=$(cat $deb_version_file|grep Ubuntu|grep -Eo '([0-9]+\.)+[0-9]+'|grep -Eo '^[0-9]+')
		if [ "${os_version}" = "" ];then
			os_type='debian'
			os_version=$(cat $deb_version_file|grep Debian|grep -Eo '([0-9]+\.)+[0-9]+'|grep -Eo '[0-9]+')
			if [ "${os_version}" = "" ];then
				os_version=$(cat $deb_version_file|grep Debian|grep -Eo '[0-9]+')
			fi
			if [ "${os_version}" = "8" ];then
				os_version=""
			fi
			if [ "${is64bit}" = '32' ];then
				os_version=""
			fi
		else
			if [ "$os_version" = "14" ];then
				os_version=""
			fi
			if [ "$os_version" = "12" ];then
				os_version=""
			fi
			if [ "$os_version" = "19" ];then
				os_version=""
			fi
		fi
	fi
}

Set_Bt_Panel(){
	chmod -R 700 /www/server/panel/pyenv/bin
	/www/server/panel/pyenv/bin/pip install cachelib
	/www/server/panel/pyenv/bin/pip install telegram
	password=$(cat /dev/urandom | head -n 16 | md5sum | head -c 8)
	sleep 1
	admin_auth="/www/server/panel/data/admin_path.pl"
	if [ ! -f ${admin_auth} ];then
		auth_path=$(cat /dev/urandom | head -n 16 | md5sum | head -c 8)
		echo "/${auth_path}" > ${admin_auth}
	fi
	auth_path=$(cat ${admin_auth})
	cd ${setup_path}/server/panel/
	if [ "$SET_SSL" == true ];then
		pip install -I pyOpenSSl
		python /www/server/panel/tools.py ssl
    fi
	/etc/init.d/bt start
	$python_bin -m py_compile tools.py
	$python_bin tools.py username
	username=$($python_bin tools.py panel ${password})
	cd ~
	echo "${password}" > ${setup_path}/server/panel/default.pl
	chmod 600 ${setup_path}/server/panel/default.pl
	sleep 3
	/etc/init.d/bt restart
	sleep 3
	isStart=$(ps aux |grep 'BT-Panel'|grep -v grep|awk '{print $2}')
	LOCAL_CURL=$(curl 127.0.0.1:8888/login 2>&1 |grep -i html)
	if [ -z "${isStart}" ] && [ -z "${LOCAL_CURL}" ];then
		/etc/init.d/bt 22
		cd /www/server/panel/pyenv/bin
		touch t.pl
		ls -al python3.7 python
		lsattr python3.7 python
		Red_Error "ERROR: The BT-Panel service startup failed."
	fi
}
Set_Firewall(){
	sshPort=$(cat /etc/ssh/sshd_config | grep 'Port '|awk '{print $2}')
	if [ "${PM}" = "apt-get" ]; then
		apt-get install -y ufw
		if [ -f "/usr/sbin/ufw" ];then
			ufw allow 20/tcp
			ufw allow 21/tcp
			ufw allow 22/tcp
			ufw allow 80/tcp
			ufw allow 888/tcp
			ufw allow 39000:40000/tcp
			ufw allow ${panelPort}/tcp
			ufw allow ${sshPort}/tcp
			ufw_status=`ufw status`
			echo y|ufw enable
			ufw default deny
			ufw reload
		fi
	else
		if [ -f "/etc/init.d/iptables" ];then
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 20 -j ACCEPT
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 21 -j ACCEPT
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 22 -j ACCEPT
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport ${panelPort} -j ACCEPT
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport ${sshPort} -j ACCEPT
			iptables -I INPUT -p tcp -m state --state NEW -m tcp --dport 39000:40000 -j ACCEPT
			#iptables -I INPUT -p tcp -m state --state NEW -m udp --dport 39000:40000 -j ACCEPT
			iptables -A INPUT -p icmp --icmp-type any -j ACCEPT
			iptables -A INPUT -s localhost -d localhost -j ACCEPT
			iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
			iptables -P INPUT DROP
			service iptables save
			sed -i "s#IPTABLES_MODULES=\"\"#IPTABLES_MODULES=\"ip_conntrack_netbios_ns ip_conntrack_ftp ip_nat_ftp\"#" /etc/sysconfig/iptables-config
			iptables_status=$(service iptables status | grep 'not running')
			if [ "${iptables_status}" == '' ];then
				service iptables restart
			fi
		else
			AliyunCheck=$(cat /etc/redhat-release|grep "Aliyun Linux")
			[ "${AliyunCheck}" ] && return
			yum install firewalld -y
			[ "${Centos8Check}" ] && yum reinstall python3-six -y
			systemctl enable firewalld
			systemctl start firewalld
			firewall-cmd --set-default-zone=public > /dev/null 2>&1
			firewall-cmd --permanent --zone=public --add-port=20/tcp > /dev/null 2>&1
			firewall-cmd --permanent --zone=public --add-port=21/tcp > /dev/null 2>&1
			firewall-cmd --permanent --zone=public --add-port=22/tcp > /dev/null 2>&1
			firewall-cmd --permanent --zone=public --add-port=80/tcp > /dev/null 2>&1
			firewall-cmd --permanent --zone=public --add-port=${panelPort}/tcp > /dev/null 2>&1
			firewall-cmd --permanent --zone=public --add-port=${sshPort}/tcp > /dev/null 2>&1
			firewall-cmd --permanent --zone=public --add-port=39000-40000/tcp > /dev/null 2>&1
			#firewall-cmd --permanent --zone=public --add-port=39000-40000/udp > /dev/null 2>&1
			firewall-cmd --reload
		fi
	fi
}
Get_Ip_Address(){
	getIpAddress=""
# 	getIpAddress=$(curl -sS --connect-timeout 10 -m 60 https://brandnew.aapanel.com/api/common/getClientIP)
	getIpAddress=$(curl -sS --connect-timeout 10 -m 60 https://www.aapanel.com/api/common/getClientIP)
# 	if [ -z "${getIpAddress}" ] || [ "${getIpAddress}" = "0.0.0.0" ]; then
# 		isHosts=$(cat /etc/hosts|grep 'www.bt.cn')
# 		if [ -z "${isHosts}" ];then
# 			echo "" >> /etc/hosts
# 			echo "103.224.251.67 www.bt.cn" >> /etc/hosts
# 			#getIpAddress=$(curl -sS --connect-timeout 10 -m 60 https://brandnew.aapanel.com/api/common/getClientIP)
# 			getIpAddress=$(curl -sS --connect-timeout 10 -m 60 https://www.bt.cn/Api/getIpAddress)
# 			if [ -z "${getIpAddress}" ];then
# 				sed -i "/bt.cn/d" /etc/hosts
# 			fi
# 		fi
# 	fi

	ipv4Check=$($python_bin -c "import re; print(re.match('^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$','${getIpAddress}'))")
	if [ "${ipv4Check}" == "None" ];then
		ipv6Address=$(echo ${getIpAddress}|tr -d "[]")
		ipv6Check=$($python_bin -c "import re; print(re.match('^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$','${ipv6Address}'))")
		if [ "${ipv6Check}" == "None" ]; then
			getIpAddress="SERVER_IP"
		else
			echo "True" > ${setup_path}/server/panel/data/ipv6.pl
			sleep 1
			/etc/init.d/bt restart
		fi
	fi

	if [ "${getIpAddress}" != "SERVER_IP" ];then
		echo "${getIpAddress}" > ${setup_path}/server/panel/data/iplist.txt
	fi
}
Setup_Count(){
    curl -sS --connect-timeout 10 -m 60 https://brandnew.aapanel.com/api/setupCount/setupPanel?type=Linux > /dev/null 2>&1
    # curl -sS --connect-timeout 10 -m 60 https://console.aapanel.com/Api/SetupCount?type=Linux > /dev/null 2>&1
	if [ "$1" != "" ];then
		echo $1 > /www/server/panel/data/o.pl
		cd /www/server/panel
		$python_bin tools.py o
	fi
	echo /www > /var/bt_setupPath.conf
}

Install_Main(){
	setenforce 0
	startTime=`date +%s`
	Lock_Clear
	System_Check
	#Set_Ssl
	Get_Pack_Manager
	get_node_url

	MEM_TOTAL=$(free -g|grep Mem|awk '{print $2}')
	if [ "${MEM_TOTAL}" -le "1" ];then
		Auto_Swap
	fi

					 
	if [ "${PM}" = "yum" ]; then
		Install_RPM_Pack
	elif [ "${PM}" = "apt-get" ]; then
		Install_Deb_Pack
	fi

	Install_Python_Lib
	Install_Bt

	Set_Bt_Panel
	Service_Add
	Set_Firewall

	Get_Ip_Address
	Setup_Count ${IDC_CODE}
}

echo "
+----------------------------------------------------------------------
| aaPanel 6.0 FOR CentOS/Ubuntu/Debian
+----------------------------------------------------------------------
| Copyright © 2015-2099 BT-SOFT(http://www.aapanel.com) All rights reserved.
+----------------------------------------------------------------------
| The WebPanel URL will be http://SERVER_IP:8888 when installed.
+----------------------------------------------------------------------
"

while [ "$go" != 'y' ] && [ "$go" != 'n' ]
do
	read -p "Do you want to install aaPanel to the $setup_path directory now?(y/n): " go;
done

if [ "$go" == 'n' ];then
	exit;
fi

Install_Main
intenal_ip=$(ip addr | grep -E -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -E -v "^127\.|^255\.|^0\." | head -n 1)
echo -e "=================================================================="
echo -e "\033[32mCongratulations! Installed successfully!\033[0m"
echo -e "=================================================================="
if [ "$SET_SSL" == true ];then
        echo  "aaPanel Internet Address: https://${getIpAddress}:${panelPort}$auth_path"
		echo  "aaPanel Internal Address: https://${intenal_ip}:${panelPort}$auth_path"
else
        echo "aaPanel Internet Address: http://${getIpAddress}:${panelPort}$auth_path"
		echo "aaPanel Internal Address: http://${intenal_ip}:${panelPort}$auth_path"
fi
echo -e "username: $username"
echo -e "password: $password"
echo -e "\033[33mWarning:\033[0m"
echo -e "\033[33mIf you cannot access the panel, \033[0m"
echo -e "\033[33mrelease the following port (8888|888|80|443|20|21) in the security group\033[0m"
echo -e "=================================================================="

endTime=`date +%s`
((outTime=($endTime-$startTime)/60))
echo -e "Time consumed:\033[32m $outTime \033[0mMinute!"
rm -f install-ubuntu_6.0_en.sh


