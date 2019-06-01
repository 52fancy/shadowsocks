#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

clear
echo "+------------------------------------------------------------------------+"
echo "|                   Shadowsocks & ShadowsocksR                           |"
echo "+------------------------------------------------------------------------+"
echo "|                 Welcome to  http://github.com/52fancy                  |"
echo "+------------------------------------------------------------------------+"

echo "请选择操作"
echo ""
echo "1.添加新用户"
echo "2.重启服务"
echo ""
while :; do echo
	read -p "请选择： " action
	if [[ ! $action =~ ^[1-2]$ ]]; then
		echo "输入错误! 请输入正确的数字!"
	else
		break	
	fi
done

if [[ $action == "1" ]]; then
    echo "Please input password:"
    read -p "(Default password: 123456):" shadowsockspwd
    [ -z "${shadowsockspwd}" ] && shadowsockspwd="123456"
    echo
    echo "---------------------------"
    echo "password = ${shadowsockspwd}"
    echo "---------------------------"
    echo
    # Set Shadowsocks config port
	
    read -p "输入域名/IP：" shadowsocksip
    [ -z "${shadowsocksip}" ] && shadowsocksip=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    echo
    echo "---------------------------"
    echo "域名/IP = ${shadowsocksip}"
    echo "---------------------------"
    echo
	
	rand(){  
		min=$1  
		max=$(($2-$min+1))  
		num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')  
		echo $(($num%$max+$min))  
	}
	
    # Set Shadowsocks config port
	[ ! -e /etc/shadowsocks.json ] && { echo "SSR is not installed!"; exit 1; }
	while :;do
		shadowsocksport=$(rand 20000 30000)
		port=`netstat -anlt | awk '{print $4}' | sed -e '1,2d' | awk -F : '{print $NF}' | sort -n | uniq | grep "$shadowsocksport"`
		if [ -z "$(grep \"${shadowsocksport}\" /etc/shadowsocks.json)" ] | [ -z ${port} ];then
			sed -i "s@\"port_password\":{@\"port_password\":{\n\t\"${shadowsocksport}\":\"${shadowsockspwd}\",@" /etc/shadowsocks.json || { echo "${shadowsocksport}This port is already in /etc/shadowsocks.json"; exit 1; }
			break
		fi
	done
	
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
	service shadowsocks restart
	
	ssmsg=`printf aes-256-cfb:$shadowsockspwd@$shadowsocksip:$shadowsocksport | base64`
	qrcode=`curl -m 10 -s http://suo.im/api.php?url=http://qr.topscan.com/api.php?text=ss://$ssmsg`
	
	clear
	echo
	echo -e "用户添加成功!"
	echo -e "Your Server IP: 	\033[41;37m ${shadowsocksip} \033[0m"	
	echo -e "Your Server Port: 	\033[41;37m ${shadowsocksport} \033[0m"
	echo -e "Your Password: 		\033[41;37m ${shadowsockspwd} \033[0m"
	echo -e "二维码地址: 		\033[41;37m ${qrcode} \033[0m"
	echo
fi

if [[ $action == "2" ]]; then
    service shadowsocks restart
fi
