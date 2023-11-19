#!/bin/bash

random() {
  tr </dev/urandom -dc A-Za-z0-9 | head -c5
  echo
}

install_squid() {
  echo "Installing Squid..."
  apt-get update
  apt-get install -y squid apache2-utils
}

configure_squid() {
  echo "Configuring Squid..."
  cp /etc/squid/squid.conf /etc/squid/squid.conf.bak

  cat <<EOF > /etc/squid/squid.conf
acl localnet src 0.0.0.1-0.255.255.255
acl localnet src 10.0.0.0/8
acl localnet src 100.64.0.0/10
acl localnet src 169.254.0.0/16
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16
acl localnet src fc00::/7
acl localnet src fe80::/10

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all

EOF

  for port in $(seq $MIN_PORT $MAX_PORT); do
    echo "http_port $port" >> /etc/squid/squid.conf
  done

  systemctl restart squid
}

gen_squid_proxy_file_for_user() {
  cat >squid_proxy.txt <<EOF
$(awk '{print $1 ":" $2}' /etc/squid/squid_passwd)
EOF
}

gen_data() {
  seq $FIRST_PORT $LAST_PORT | while read port; do
    user="usr$(random)"
    pass="$(random)"
    echo "$user:$pass" >> /etc/squid/squid_passwd
    echo "$user:$pass@$IP4:$port"
  done
}

echo "Installing apps"
install_squid

echo "Working folder = /home/squid-installer"
WORKDIR="/home/squid-installer"
mkdir -p $WORKDIR && cd $WORKDIR

echo "Enter the range for the ports (e.g., 10000 to 11000)"
read -p "Minimum port: " MIN_PORT
read -p "Maximum port: " MAX_PORT

if [[ $MIN_PORT -gt $MAX_PORT ]]; then
  echo "Invalid port range. Please make sure the minimum port is less than or equal to the maximum port."
  exit 1
fi

gen_data > $WORKDIR/proxy_list.txt
gen_squid_proxy_file_for_user

configure_squid

echo "Squid proxies are ready!"
echo "Proxy list saved to: ${WORKDIR}/proxy_list.txt"
echo "Proxy credentials saved to: /etc/squid/squid_passwd"
