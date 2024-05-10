#!/bin/bash

apt update 
apt upgrade
apt install haproxy -y

export ipaddr=`ip address|grep eth0|grep inet|awk -F ' ' '{print $2}' |awk -F '/' '{print $1}'`
export pubip=`dig +short myip.opendns.com @resolver1.opendns.com`

cat >> /etc/haproxy/haproxy.cfg <<EOL 
    frontend kubernetes-frontend
        bind $ipaddr:6443
        mode tcp
        option tcplog
        default_backend kubernetes-backend

    backend kubernetes-backend
        mode tcp
        option tcp-check
        balance roundrobin
        server kmaster1 ${master_1}:6443 check fall 3 rise 2
        server kmaster2 ${master_2}:6443 check fall 3 rise 2
       
EOL

systemctl restart haproxy