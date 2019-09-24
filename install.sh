#!/bin/bash

#====================================================
#	System Request:Debian 7+/Ubuntu 14.04+/Centos 6+
#	Author:	wulabing
#	Dscription: V2ray ws+tls onekey 
#	Version: 3.3.1
#	Blog: https://www.wulabing.com
#	Official document: www.v2ray.com
#====================================================

#fonts color
Green="\033[32m" 
Red="\033[31m" 
Yellow="\033[33m"
GreenBG="\033[42;37m"
RedBG="\033[41;37m"
Font="\033[0m"

#notification information
Info="${Green}[정보]${Font}"
OK="${Green}[OK]${Font}"
Error="${Red}[오류]${Font}"

v2ray_conf_dir="/etc/v2ray"
nginx_conf_dir="/etc/nginx/conf.d"
v2ray_conf="${v2ray_conf_dir}/config.json"
nginx_conf="${nginx_conf_dir}/v2ray.conf"

#위장 경로 생성
camouflage=`cat /dev/urandom | head -n 10 | md5sum | head -c 8`

source /etc/os-release

#VERSION 중 시스템 영문명을 가져와서 debian/ubuntu에서 적합한 Nginx apt 찾아냄
VERSION=`echo ${VERSION} | awk -F "[()]" '{print $2}'`

check_system(){
    
    if [[ "${ID}" == "centos" && ${VERSION_ID} -ge 7 ]];then
        echo -e "${OK} ${GreenBG} 현재 시스템은 Centos ${VERSION_ID} ${VERSION} ${Font} 입니다."
        INS="yum"
        echo -e "${OK} ${GreenBG} SElinux 설정 중，기다려 주시기 바랍니다. 기타 조작은 하지 말아 주세요.${Font} "
        setsebool -P httpd_can_network_connect 1
        echo -e "${OK} ${GreenBG} SElinux 설정 완료 ${Font} "
        ## Centos 도 epel 저장소를 통해 설치 가능하나, 아직 수정 안함.
        cat>/etc/yum.repos.d/nginx.repo<<EOF
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/mainline/centos/7/\$basearch/
gpgcheck=0
enabled=1
EOF
        echo -e "${OK} ${GreenBG} Nginx 설치 완료 ${Font}" 
    elif [[ "${ID}" == "debian" && ${VERSION_ID} -ge 8 ]];then
        echo -e "${OK} ${GreenBG} 현재 시스템은 Debian ${VERSION_ID} ${VERSION} ${Font} 입니다. "
        INS="apt"
        ## 添加 Nginx apt源
        if [ ! -f nginx_signing.key ];then
        echo "deb http://nginx.org/packages/mainline/debian/ ${VERSION} nginx" >> /etc/apt/sources.list
        echo "deb-src http://nginx.org/packages/mainline/debian/ ${VERSION} nginx" >> /etc/apt/sources.list
        wget -nc https://nginx.org/keys/nginx_signing.key
        apt-key add nginx_signing.key
        fi
    elif [[ "${ID}" == "ubuntu" && `echo "${VERSION_ID}" | cut -d '.' -f1` -ge 16 ]];then
        echo -e "${OK} ${GreenBG} 현재 시스템은 Ubuntu ${VERSION_ID} ${VERSION_CODENAME} ${Font} 입니다."
        INS="apt"
        ## 添加 Nginx apt源
        if [ ! -f nginx_signing.key ];then
        echo "deb http://nginx.org/packages/mainline/ubuntu/ ${VERSION_CODENAME} nginx" >> /etc/apt/sources.list
        echo "deb-src http://nginx.org/packages/mainline/ubuntu/ ${VERSION_CODENAME} nginx" >> /etc/apt/sources.list
        wget -nc https://nginx.org/keys/nginx_signing.key
        apt-key add nginx_signing.key
        fi
    else
        echo -e "${Error} ${RedBG} 현재 시스템은 ${ID} ${VERSION_ID} 이며 지원하지 않는 시스템입니다. 설치를 중단합니다. ${Font} "
        exit 1
    fi

}
is_root(){
    if [ `id -u` == 0 ]
        then echo -e "${OK} ${GreenBG} 현재 사용자는 root 계정입니다. 설치를 진행합니다. ${Font} "
        sleep 3
    else
        echo -e "${Error} ${RedBG} 현재 사용자는 root 계정이 아닙니다. root계정으로 전환 후 스크립트를 다시 실행해 주세요. ${Font}" 
        exit 1
    fi
}
judge(){
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} $1 완료 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 실패${Font}"
        exit 1
    fi
}
ntpdate_install(){
    if [[ "${ID}" == "centos" ]];then
        ${INS} install ntpdate -y
    else
        ${INS} update
        ${INS} install ntpdate -y
    fi
    judge "NTPdate 시간 동기화서비스 설치 "
}
time_modify(){

    ntpdate_install

    systemctl stop ntp &>/dev/null

    echo -e "${Info} ${GreenBG} 시간 동기화 진행 중 ${Font}"
    ntpdate time.nist.gov

    if [[ $? -eq 0 ]];then 
        echo -e "${OK} ${GreenBG} 시간 동기화 성공 ${Font}"
        echo -e "${OK} ${GreenBG} 현재 시스템 시간 `date -R`（각 시차 구간별로 시간을 환산하면 3분 이내여야 합니다.）${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} 시간 동기화 실패, ntpdate 서비스가 정상적으로 실행 중인지 확인하세요. ${Font}"
    fi 
}
dependency_install(){
    ${INS} install wget git lsof -y

    if [[ "${ID}" == "centos" ]];then
       ${INS} -y install crontabs
    else
        ${INS} install cron
    fi
    judge "crontab 설치"

    # 새 버전의 IP판정은 net-tools를 사용하지 않아도 됨
    # ${INS} install net-tools -y
    # judge "net-tools 설치"

    ${INS} install bc -y
    judge "bc 설치"

    ${INS} install unzip -y
    judge "unzip 설치"
}
port_alterid_set(){
    stty erase '^H' && read -p "연결 포트를 입력하세요（default:443）:" port
    [[ -z ${port} ]] && port="443"
    stty erase '^H' && read -p "alterID를 입력하세요（default:64）:" alterID
    [[ -z ${alterID} ]] && alterID="64"
}
modify_port_UUID(){
    let PORT=$RANDOM+10000
    UUID=$(cat /proc/sys/kernel/random/uuid)
    sed -i "/\"port\"/c  \    \"port\":${PORT}," ${v2ray_conf}
    sed -i "/\"id\"/c \\\t  \"id\":\"${UUID}\"," ${v2ray_conf}
    sed -i "/\"alterId\"/c \\\t  \"alterId\":${alterID}" ${v2ray_conf}
    sed -i "/\"path\"/c \\\t  \"path\":\"\/${camouflage}\/\"" ${v2ray_conf}
}
modify_nginx(){
    ## sed 部分地方 适应新配置修正
    if [[ -f /etc/nginx/nginx.conf.bak ]];then
        cp /etc/nginx/nginx.conf.bak /etc/nginx/nginx.conf
    fi
    sed -i "1,/listen/{s/listen 443 ssl;/listen ${port} ssl;/}" ${nginx_conf}
    sed -i "/server_name/c \\\tserver_name ${domain};" ${nginx_conf}
    sed -i "/location/c \\\tlocation \/${camouflage}\/" ${nginx_conf}
    sed -i "/proxy_pass/c \\\tproxy_pass http://127.0.0.1:${PORT};" ${nginx_conf}
    sed -i "/return/c \\\treturn 301 https://${domain}\$request_uri;" ${nginx_conf}
    sed -i "27i \\\tproxy_intercept_errors on;"  /etc/nginx/nginx.conf
}
web_camouflage(){
    ##주의: 이곳과 LNMP 스크립트의 경로가 충돌하는 경우, 절대 LNMP 환경에서 본 스크립트를 사용하지 마세요. 결과는 본인이 책임 지셔야 합니다.
    rm -rf /home/wwwroot && mkdir -p /home/wwwroot && cd /home/wwwroot
    git clone https://github.com/wulabing/sCalc.git
    judge "web 위장"   
}
v2ray_install(){
    if [[ -d /root/v2ray ]];then
        rm -rf /root/v2ray
    fi

    mkdir -p /root/v2ray && cd /root/v2ray
    wget  --no-check-certificate https://install.direct/go.sh

    ## wget http://install.direct/go.sh
    
    if [[ -f go.sh ]];then
        bash go.sh --force
        judge "V2ray 설치"
    else
        echo -e "${Error} ${RedBG} V2ray 설치 파일 다운로드 실패，다운로드 주소가 사용 가능한지 확인하세요. ${Font}"
        exit 4
    fi
}
nginx_install(){
    ${INS} install nginx -y
    if [[ -d /etc/nginx ]];then
        echo -e "${OK} ${GreenBG} nginx 설치 완료 ${Font}"
        sleep 2
    else
        echo -e "${Error} ${RedBG} nginx 설치 실패 ${Font}"
        exit 5
    fi
    if [[ ! -f /etc/nginx/nginx.conf.bak ]];then
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak
        echo -e "${OK} ${GreenBG} nginx 초기 설정 백업 완료 ${Font}"
        sleep 1
    fi
}
ssl_install(){
    if [[ "${ID}" == "centos" ]];then
        ${INS} install socat nc -y        
    else
        ${INS} install socat netcat -y
    fi
    judge "SSL 증서 생성 스크립트 의존성 파일 설치"

    curl  https://get.acme.sh | sh
    judge "SSL 증서 생성 스크립트 설치"

}
domain_check(){
    stty erase '^H' && read -p "도메인 정보를 입력해주세요(eg:www.wulabing.com):" domain
    domain_ip=`ping ${domain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    echo -e "${OK} ${GreenBG} 공인ip 정보 확인 중，기다려 주세요 ${Font}"
    local_ip=`curl -4 ip.sb`
    echo -e "도메인에 대해 dns로 확인된 IP：${domain_ip}"
    echo -e "서버 IP: ${local_ip}"
    sleep 2
    if [[ $(echo ${local_ip}|tr '.' '+'|bc) -eq $(echo ${domain_ip}|tr '.' '+'|bc) ]];then
        echo -e "${OK} ${GreenBG} 도메인에 대한 dns 확인 IP 와 서버 IP가 일치하지 않습니다. ${Font}"
        sleep 2
    else
        echo -e "${Error} ${RedBG} 도메인에 대한 dns 확인 IP 와 서버 IP가 일치하지 않습니다. 계속 설치하시겠습니까?（y/n）${Font}" && read install
        case $install in
        [yY][eE][sS]|[yY])
            echo -e "${GreenBG} 계속 설치 ${Font}" 
            sleep 2
            ;;
        *)
            echo -e "${RedBG} 설치 중단 ${Font}" 
            exit 2
            ;;
        esac
    fi
}

port_exist_check(){
    if [[ 0 -eq `lsof -i:"$1" | wc -l` ]];then
        echo -e "${OK} ${GreenBG} $1 포트 사용 가능 ${Font}"
        sleep 1
    else
        echo -e "${Error} ${RedBG} $1 포트가 이미 사용 중입니다.端口被占用，아래는 $1 포트 사용 정보입니다. ${Font}"
        lsof -i:"$1"
        echo -e "${OK} ${GreenBG} 5초 후 포트를 사용하는 프로세스를 kill 합니다. ${Font}"
        sleep 5
        lsof -i:"$1" | awk '{print $2}'| grep -v "PID" | xargs kill -9
        echo -e "${OK} ${GreenBG} kill 완료 ${Font}"
        sleep 1
    fi
}
acme(){
    ~/.acme.sh/acme.sh --issue -d ${domain} --standalone -k ec-256 --force
    if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} SSL 증서 생성 완료 ${Font}"
        sleep 2
        ~/.acme.sh/acme.sh --installcert -d ${domain} --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
        if [[ $? -eq 0 ]];then
        echo -e "${OK} ${GreenBG} 증서 설정 완료 ${Font}"
        sleep 2
        fi
    else
        echo -e "${Error} ${RedBG} SSL 증서 생성 실패 ${Font}"
        exit 1
    fi
}
v2ray_conf_add(){
    cd /etc/v2ray
    wget https://raw.githubusercontent.com/wulabing/V2Ray_ws-tls_bash_onekey/master/tls/config.json -O config.json
modify_port_UUID
judge "V2ray 설정 수정"
}
nginx_conf_add(){
    touch ${nginx_conf_dir}/v2ray.conf
    cat>${nginx_conf_dir}/v2ray.conf<<EOF
    server {
        listen 443 ssl;
        ssl on;
        ssl_certificate       /etc/v2ray/v2ray.crt;
        ssl_certificate_key   /etc/v2ray/v2ray.key;
        ssl_protocols         TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers           HIGH:!aNULL:!MD5;
        server_name           serveraddr.com;
        index index.html index.htm;
        root  /home/wwwroot/sCalc;
        error_page 400 = /400.html;
        location /ray/ 
        {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        }
}
    server {
        listen 80;
        server_name serveraddr.com;
        return 301 https://use.shadowsocksr.win\$request_uri;
    }
EOF

modify_nginx
judge "Nginx 설치 수정"

}

start_process_systemd(){
    ### nginx서비스는 서치 완료후 자동 시작됩니다. restart 또는 reload를 통해 설정을 다시 불러옵니다.
    systemctl start nginx 
    judge "Nginx 시작"

    systemctl enable nginx
    judge "Nginx 자동 시작 설정"

    systemctl start v2ray
    judge "V2ray 시작"
}

acme_cron_update(){
    if [[ "${ID}" == "centos" ]];then
        sed -i "/acme.sh/c 0 0 * * 0 systemctl stop nginx && \"/root/.acme.sh\"/acme.sh --cron --home \"/root/.acme.sh\" \
        > /dev/null && systemctl start nginx " /var/spool/cron/root
    else
        sed -i "/acme.sh/c 0 0 * * 0 systemctl stop nginx && \"/root/.acme.sh\"/acme.sh --cron --home \"/root/.acme.sh\" \
        > /dev/null && systemctl start nginx " /var/spool/cron/crontabs/root
    fi
    judge "cron 스케쥴 갱신"
}
show_information(){
    clear

    echo -e "${OK} ${Green} V2ray+ws+tls 설치 완료 "
    echo -e "${Red} V2ray 설정 정보 ${Font}"
    echo -e "${Red} 주소（address）:${Font} ${domain} "
    echo -e "${Red} 포트（port）：${Font} ${port} "
    echo -e "${Red} 사용자id（UUID）：${Font} ${UUID}"
    echo -e "${Red} 额外id（alterId）：${Font} ${alterID}"
    echo -e "${Red} 암호화 방식（security）：${Font} 自适应 "
    echo -e "${Red} 전송프로토콜（network）：${Font} ws "
    echo -e "${Red} 위장종류（type）：${Font} none "
    echo -e "${Red} 경로（/빼먹지 마세요）：${Font} /${camouflage}/ "
    echo -e "${Red} 저수준 전송 보안：${Font} tls "

    

}

main(){
    is_root
    check_system
    time_modify
    dependency_install
    domain_check
    port_alterid_set
    v2ray_install
    port_exist_check 80
    port_exist_check ${port}
    nginx_install
    v2ray_conf_add
    nginx_conf_add
    web_camouflage

    #증서 설치 위치 변경하면, 포트 충돌을 방지하기 위해서 관련 프로그램을 종료해주세요.
    systemctl stop nginx
    systemctl stop v2ray
    
    #증서생성완료후,증서를 여러번 신청하는 것을 방지하기 위해서 스크립트를 여러번 실행하지 마세요.
    ssl_install
    acme
    
    show_information
    start_process_systemd
    acme_cron_update
}

main
