#!/bin/bash
#
# File to get jitsi configured on DO Droplet
#
DOMAIN="linux-ottawa.org"
SERVER="$1"
HOST="host"
HOSTPW="hosting123"

if [ "X${SERVER}" = "X" ]; then
  echo "No server name supplied!"
  echo "Usage: build_jitsi <servername>"
  exit 1
fi

echo "Before you do anything else, set the DNS record!"
echo "Hit any key to continue"
read

# Update system
apt-get -y update
apt-get -y upgrade

# Installing Glances so we can see the system behaviour
apt-get -y install glances

# set the hostname to our FQDN

hostnamectl set-hostname ${SERVER}.${DOMAIN}

# Make sure jitsi can accet the server via loopback
echo "127.0.0.1   ${SERVER}.${DOMAIN}" > /etc/hosts

# Configure the firewall
ufw enable
ufw status
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 4443/tcp
ufw allow 10000/udp
ufw allow OpenSSH
ufw status

# Add the jitsi apt key
wget https://download.jitsi.org/jitsi-key.gpg.key
apt-key add jitsi-key.gpg.key

# add the jitsi source to the server
echo "deb https://download.jitsi.org stable/" >> /etc/apt/sources.list.d/jitsi-stable.list

# update apt to look there
apt update

# Install jitsi
apt install -y jitsi-meet

# Do the same for let's encrypt
add-apt-repository ppa:certbot/certbot
apt install certbot

# Now add a proper SSL cert to our jitsi install
/usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

# Now that we have passed the test, disable port 80 access
ufw delete allow 80/tcp
ufw status

# Set up meeting authentication so our server does not host random meetings

# This based on various tutorials and examining the files. If 
# I continue doing this it will be an Ansible playbook for the 
# configuration

sed -i 's/authentication = "anonymous"/authentication = "internal_plain"/' /etc/prosody/conf.avail/${SERVER}.${DOMAIN}.cfg.lua
cat >> /etc/prosody/conf.avail/${SERVER}.${DOMAIN}.cfg.lua <<EOT

VirtualHost "guest.${SERVER}.${DOMAIN}"
    authentication = "anonymous"
    c2s_require_encryption = false
EOT

sed -i 's/\/\/ anonymousdomain:/anonymousdomain:/' /etc/jitsi/meet/${SERVER}.${DOMAIN}-config.js
sed -i "s/guest.example.com/guest.${SERVER}.${DOMAIN}/" /etc/jitsi/meet/${SERVER}.${DOMAIN}-config.js
echo "org.jitsi.jicofo.auth.URL=XMPP:${SERVER}.${DOMAIN}" >> /etc/jitsi/jicofo/sip-communicator.properties

# Add the host account so we can authorize meetings
prosodyctl register ${HOST} ${SERVER}.${DOMAIN} ${HOSTPW}

# restart the services
systemctl restart prosody.service
systemctl restart jicofo.service
systemctl restart jitsi-videobridge2.service

echo "Should be up and running..."
echo "Visit https://${SERVER}.${DOMAIN} to get started"

# Additional configuration should go below.

