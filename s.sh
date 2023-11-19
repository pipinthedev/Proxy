#!/bin/bash

# Get server IP from user
echo "Enter the server IP address:"
read SERVER_IP

# Get the number of proxies to generate
read -p "Enter the number of proxies to generate: " NUM_PROXIES

# Install Squid
apt-get update
apt-get install -y squid

# Create Squid password file
touch /etc/squid/squid_passwd
chmod 600 /etc/squid/squid_passwd

# Generate proxy passwords and update Squid password file
for ((i = 1; i <= NUM_PROXIES; i++)); do
    PROXY_USER="user$i"
    PROXY_PASS=$(tr -cd '[:alnum:]' < /dev/urandom | head -c10)
    htpasswd -b /etc/squid/squid_passwd $PROXY_USER $PROXY_PASS
done

# Configure Squid
cat <<EOL > /etc/squid/squid.conf
acl SSL_ports port 443
acl Safe_ports port 80      # http
acl Safe_ports port 21      # ftp
acl Safe_ports port 443     # https
acl Safe_ports port 70      # gopher
acl Safe_ports port 210     # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280     # http-mgmt
acl Safe_ports port 488     # gss-http
acl Safe_ports port 591     # filemaker
acl Safe_ports port 777     # multiling http
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localhost
http_access deny all

http_port $SERVER_IP:10000,11000
visible_hostname proxy-server

auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/squid_passwd
auth_param basic realm proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated

forwarded_for off
via off
request_header_access Allow allow all
request_header_access Authorization allow all
request_header_access WWW-Authenticate allow all
request_header_access Proxy-Authorization allow all
request_header_access Proxy-Authenticate allow all
request_header_access Cache-Control allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Expires allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Last-Modified allow all
request_header_access Location allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Content-Language allow all
request_header_access Mime-Version allow all
request_header_access Retry-After allow all
request_header_access Title allow all
request_header_access Connection allow all
request_header_access Proxy-Connection allow all
request_header_access User-Agent allow all
request_header_access Cookie allow all
request_header_access All deny all
EOL

# Restart Squid
systemctl restart squid

# Generate proxies and save to home/proxy.txt
echo "Generating proxies..."
echo -n > /home/proxy.txt
for ((i = 1000; i <= 10000; i++)); do
    echo "${SERVER_IP}:${i}:${PROXY_USER}:${PROXY_PASS}" >> /home/proxy.txt
done

# Check proxies by pinging google.com
echo "Checking proxies..."
while IFS= read -r proxy; do
    proxy_ip=$(echo "$proxy" | cut -d':' -f1)
    ping -c 1 -W 1 -q google.com -I $proxy_ip >/dev/null
    if [ $? -eq 0 ]; then
        echo "Proxy $proxy is working."
    else
        echo "Proxy $proxy is not working."
    fi
done < /home/proxy.txt

echo "Squid installed and configured. Proxies are ready!"
