#!/bin/bash

# Get server IP from user
echo "Enter the server IP address:"
read SERVER_IP

# Get the number of proxies to generate
read -p "Enter the number of proxies to generate: " NUM_PROXIES

# Set port range for proxies
MIN_PORT=3400
MAX_PORT=4000

# Install Squid
apt-get update
apt-get install -y squid

# Create Squid password file
touch /etc/squid/squid_passwd
chmod 600 /etc/squid/squid_passwd

# Create a proxy information file
PROXY_FILE=/home/proxy.txt
echo -n > $PROXY_FILE

# Generate proxy passwords and update Squid password file
for ((i = 1; i <= NUM_PROXIES; i++)); do
    PROXY_USER="user$i"
    PROXY_PASS=$(tr -cd '[:alnum:]' < /dev/urandom | head -c10)
    htpasswd -b /etc/squid/squid_passwd $PROXY_USER $PROXY_PASS

    # Create individual configuration file for each proxy port
    PORT=$((MIN_PORT + i - 1))
    cat <<EOL > /etc/squid/squid_proxy_${PORT}.conf
http_port $SERVER_IP:$PORT
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

    # Include the proxy configuration file in the main Squid configuration
    echo "include /etc/squid/squid_proxy_${PORT}.conf" >> /etc/squid/squid.conf

    # Save proxy information to the proxy file
    echo "${SERVER_IP}:${PORT}:${PROXY_USER}:${PROXY_PASS}" >> $PROXY_FILE
done

# Restart Squid
systemctl restart squid

echo "Squid installed and configured. Proxies are ready. Proxy information saved to: $PROXY_FILE"
