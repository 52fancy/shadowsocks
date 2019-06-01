#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

rm -f $0
# Make sure only root can run our script
# Check if user is root
if [ $(id -u) != "0" ]; then
    echo "Error: You must be root to run this script, please use root to install Shadowsocks"
    exit
fi

clear
echo "+------------------------------------------------------------------------+"
echo "|                            Shadowsocks                                |"
echo "+------------------------------------------------------------------------+"
echo "|        A tool to auto-compile & install Shadowsocks on CentOS 6       |"
echo "+------------------------------------------------------------------------+"
echo "|                 Welcome to  http://github.com/                        |"
echo "+------------------------------------------------------------------------+"

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# Get public IP address
get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget --no-check-certificate -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget --no-check-certificate -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

pre_install(){
    echo "Please input password for Shadowsocks:"
    read -p "(Default password: 123456):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="123456"
    echo
    echo "---------------------------"
    echo "password = ${shadowsockspwd}"
    echo "---------------------------"
    echo
    # Set Shadowsocks config port
	
	while true
    do
    echo -e "Please input port for Shadowsocks [1-65535]:"
    read -p "(Default port: 8888):" shadowsocksport
    [ -z "${shadowsocksport}" ] && shadowsocksport="8888"
    expr ${shadowsocksport} + 0 &>/dev/null
    if [ $? -eq 0 ]; then
        if [ ${shadowsocksport} -ge 1 ] && [ ${shadowsocksport} -le 65535 ]; then
            echo
            echo "---------------------------"
            echo "port = ${shadowsocksport}"
            echo "---------------------------"
            echo
            break
        else
            echo "Input error, please input correct number"
        fi
    else
        echo "Input error, please input correct number"
    fi
    done
	
	yum install -y python python-devel python-setuptools openssl openssl-devel curl wget unzip gcc automake autoconf make libtool
	
}
# Download files
download_files(){

    # Download Shadowsocks init script
    if ! wget --no-check-certificate https://github.com/52fancy/shadowsocks/raw/master/shadowsocks -O /etc/init.d/shadowsocks ; then
        echo "Failed to download Shadowsocks chkconfig file!"
        exit 1
    fi
	
	if ! wget --no-check-certificate https://github.com/52fancy/shadowsocks/raw/master/ss -O /bin/shadowsocks ; then
        echo "Failed to download Shadowsocks chkconfig file!"
        exit 1
    fi
	chmod +x /bin/shadowsocks
	
	if ! wget --no-check-certificate -O libsodium-1.0.17.tar.gz https://github.com/52fancy/shadowsocks/raw/master/libsodium-1.0.17.tar.gz ; then
        echo "Failed to download libsodium-1.0.17.tar.gz!"
        exit 1
    fi
	
    if ! wget --no-check-certificate -O shadowsocks-master.zip https://github.com/52fancy/shadowsocks/raw/master/shadowsocks-master.zip ; then
        echo "Failed to download Shadowsocks file!"
        exit 1
    fi
}

firewall_set(){
    echo "firewall set start..."
    if [ $? -eq 0 ]; then
        iptables -L -n | grep -i ${shadowsocksport} > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            iptables -I INPUT -m tcp -p tcp --dport ${shadowsocksport} -j ACCEPT
            iptables -I INPUT -m udp -p udp --dport ${shadowsocksport} -j ACCEPT
            /etc/init.d/iptables save
            /etc/init.d/iptables restart
        else
            echo "port ${shadowsocksport} has been set up."
        fi
    else
        echo "WARNING: iptables looks like shutdown or not installed, please manually set it if necessary."
    fi    
    echo "firewall set completed..."
}

# Config Shadowsocks
config_shadowsocks(){
    cat > /etc/shadowsocks.json<<-EOF
{
    "server":"0.0.0.0",
    "local_address":"127.0.0.1",
    "local_port":1080,
    "port_password":{
	    "${shadowsocksport}":"${shadowsockspwd}"
    },
    "timeout":300,
    "method":"aes-256-cfb",
    "fast_open": false
}
EOF
}

install(){	
	# Install libsodium
    if [ ! -f /usr/lib/libsodium.a ]; then
		tar zxf libsodium-1.0.17.tar.gz
		cd libsodium-1.0.17
        ./configure --prefix=/usr && make && make install
        if [ $? -ne 0 ]; then
            echo -e "[${red}Error${plain}] libsodium install failed!"
            install_cleanup
            exit 1
        fi
    fi
	
    ldconfig
    # Install Shadowsocks
    cd 
	unzip -q shadowsocks-master.zip
	cd shadowsocks-master
    python setup.py install --record /usr/local/shadowsocks_install.log
	
    if [ -f /usr/bin/ssserver ] || [ -f /usr/local/bin/ssserver ]; then
        chmod +x /etc/init.d/shadowsocks
        chkconfig --add shadowsocks
        chkconfig shadowsocks on
        /etc/init.d/shadowsocks start

        clear
        echo
        echo "Congratulations, Shadowsocks install completed!"
        echo -e "Server IP: \033[41;37m $(get_ip) \033[0m"
        echo -e "Server Port: \033[41;37m ${shadowsocksport} \033[0m"
        echo -e "Password: \033[41;37m ${shadowsockspwd} \033[0m"
        echo -e "Local IP: \033[41;37m 127.0.0.1 \033[0m"
        echo -e "Local Port: \033[41;37m 1080 \033[0m"
        echo -e "Encryption Method: \033[41;37m aes-256-cfb \033[0m"
        echo
        echo "Welcome to visit:https://github.com/"
        echo "Enjoy it!"
        echo
    else
        echo "Shadowsocks install failed, please Web to https://github.com/ and contact"
        install_cleanup
        exit 1
    fi
}

# Install cleanup
install_cleanup(){
    cd 
    rm -rf shadowsocks-master.zip shadowsocks-master libsodium-1.0.17.tar.gz libsodium-1.0.17
}


# Uninstall Shadowsocks
uninstall_shadowsocks(){
    printf "Are you sure uninstall Shadowsocks? (y/n) "
    printf "\n"
    read -p "(Default: n):" answer
    [ -z ${answer} ] && answer="n"
    if [ "${answer}" == "y" ] || [ "${answer}" == "Y" ]; then
        ps -ef | grep -v grep | grep -i "ssserver" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            /etc/init.d/shadowsocks stop
        fi
        chkconfig --del shadowsocks
        # delete config file
        rm -f /etc/shadowsocks.json
        rm -f /var/run/shadowsocks.pid
		rm -f /bin/ss		
        rm -f /etc/init.d/shadowsocks
        rm -f /var/log/shadowsocks.log
        if [ -f /usr/local/shadowsocks_install.log ]; then
            cat /usr/local/shadowsocks_install.log | xargs rm -rf
        fi
        echo "Shadowsocks uninstall success!"
    else
        echo
        echo "uninstall cancelled, nothing to do..."
        echo
    fi
}

# Install Shadowsocks
install_shadowsocks(){
    disable_selinux
    pre_install
    download_files
    config_shadowsocks
    firewall_set
    install
    install_cleanup
}

# Initialization step
action=$1
[ -z $1 ] && action=install
case "$action" in
    install|uninstall)
        ${action}_shadowsocks
        ;;
    *)
        echo "Arguments error! [${action}]"
        echo "Usage: `basename $0` [install|uninstall]"
    ;;
esac
