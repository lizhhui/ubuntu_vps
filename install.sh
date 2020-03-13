#!/bin/bash
#=================================
#draw.io + trojan
#=================================
blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}

blue "*** install nginx       ++++++++++++++++++++"

your_domain=0.lizhanghui.xyz

#apt-get install openjdk-8-jdk
#git clone https://github.com/jgraph/drawio.git

apt-get update 
apt-get install nginx -y

systemctl enable nginx
systemctl stop nginx

blue "*** config nginx        ++++++++++++++++++++"

cat > /etc/nginx/nginx.conf <<-EOF
user  root;
worker_processes  1;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  1024;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    sendfile        on;
    #tcp_nopush     on;
    keepalive_timeout  120;
    client_max_body_size 20m;
    #gzip  on;
    server {
        listen       80;
        server_name  $your_domain;
        root /usr/share/nginx/html;
        index index.php index.html;
    }
}
EOF

#rm -rf /usr/share/nginx/html/*

systemctl start ufw
systemctl enable ufw
ufw allow 80
ufw allow 666

systemctl stop ufw
systemctl disable ufw

blue "*** trojan cert         ++++++++++++++++++++"

mkdir /usr/src/trojan-cert /usr/src/trojan-temp
rm /usr/src/trojan-cert/* -fr
rm /usr/src/trojan-temp/* -fr

curl https://get.acme.sh | sh
~/.acme.sh/acme.sh  --issue  -d $your_domain  --standalone
~/.acme.sh/acme.sh  --installcert  -d  $your_domain   --key-file   /usr/src/trojan-cert/private.key --fullchain-file /usr/src/trojan-cert/fullchain.cer

blue "*** start nginx         ++++++++++++++++++++"

systemctl start nginx
systemctl enable nginx

blue "*** install trojan      ++++++++++++++++++++"
cd /usr/src
wget https://api.github.com/repos/trojan-gfw/trojan/releases/latest
latest_version=`grep tag_name latest| awk -F '[:,"v]' '{print $6}'`
wget https://github.com/trojan-gfw/trojan/releases/download/v${latest_version}/trojan-${latest_version}-linux-amd64.tar.xz
tar xf trojan-${latest_version}-linux-amd64.tar.xz


blue "*** config trojan       ++++++++++++++++++++"
cat > /usr/src/trojan/server.conf <<-EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 666,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "123qwetrojan"
    ],
    "log_level": 1,
    "ssl": {
        "cert": "/usr/src/trojan-cert/fullchain.cer",
        "key": "/usr/src/trojan-cert/private.key",
        "key_password": "",
        "cipher_tls13":"TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
	"prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "no_delay": true,
        "keep_alive": true,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": ""
    }
}
EOF

#增加启动脚本	
cat > /lib/systemd/system/trojan.service <<-EOF
[Unit]  
Description=trojan  
After=network.target  
   
[Service]  
Type=simple  
PIDFile=/usr/src/trojan/trojan/trojan.pid
ExecStart=/usr/src/trojan/trojan -c "/usr/src/trojan/server.conf"  
ExecReload=  
ExecStop=/usr/src/trojan/trojan  
PrivateTmp=true  
   
[Install]  
WantedBy=multi-user.target
EOF

blue "*** start trojan        ++++++++++++++++++++"
chmod +x /lib/systemd/system/trojan.service 
systemctl start trojan.service
systemctl enable trojan.service

#======================
#BBR speed up
#^^^^^^^^^^^^^^^^^^^^^^
blue "*** bbr install         ++++++++++++++++++++"
#set 
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
#avliable
sysctl -p
# check out
sysctl net.ipv4.tcp_available_congestion_control
sysctl net.ipv4.tcp_congestion_control
lsmod | grep bbr

wget -N --no-check-certificate https://raw.githubusercontent.com/lizhhui/ubuntu_vps/master/install.sh && chmod +x install.sh && ./install.sh
