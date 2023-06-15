#!/bin/bash

# Update the system
sudo apt update

# Install Nginx
sudo apt install -y nginx

# Set up Nginx with three worker processes
sudo sed -i 's/worker_processes 1/worker_processes 3/' /etc/nginx/nginx.conf

# Enable access logs and specify log location
sudo sed -i '/access_log/s/#//g' /etc/nginx/nginx.conf
sudo sed -i 's|access_log .*|access_log /var/log/nginx/access.log;|' /etc/nginx/nginx.conf

# Create a basic HTML page
sudo bash -c 'cat <<EOF > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
<title>Course Name</title>
</head>
<body>
<h1>Course Name</h1>
<p>Welcome to our course website!</p>
</body>
</html>
EOF'

# Set appropriate permissions for the HTML file
sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

# Install logrotate package for log rotation
sudo apt install -y logrotate

# Configure log rotation for Nginx access log
sudo bash -c 'cat <<EOF > /etc/logrotate.d/nginx
/var/log/nginx/access.log {
    rotate 7
    daily
    missingok
    notifempty
    compress
    delaycompress
    sharedscripts
    postrotate
        systemctl reload nginx
    endscript
}
EOF'

# Set permanent firewall rules
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -s 192.168.0.0/24 -j ACCEPT
sudo iptables -A INPUT -j DROP

# Save firewall rules
sudo iptables-save | sudo tee /etc/iptables/rules.v4

# Limit memory usage for nginx.service
sudo bash -c 'cat <<EOF > /etc/systemd/system/nginx.service.d/memory.conf
[Service]
MemoryMax=1G
EOF'

# Reload systemd configuration
sudo systemctl daemon-reload

# Generate a self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt -subj "/C=US/ST=State/L=City/O=Organization/CN=jamilali.rf.gd"

# Enable SSL in Nginx configuration
sudo sed -i '/listen 443 ssl/s/#//g' /etc/nginx/sites-available/default
sudo sed -i '/ssl_certificate/s|# \(.*\)|\1|' /etc/nginx/sites-available/default
sudo sed -i '/ssl_certificate_key/s|# \(.*\)|\1|' /etc/nginx/sites-available/default

# Create a rule to redirect HTTP traffic to HTTPS
sudo sed -i '/listen 80 default_server;/s|# \(.*\)|\1|' /etc/nginx/sites-available/default
sudo bash -c 'cat <<EOF >> /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    server_name _;
    return 301 https://\$host\$request_uri;
}
EOF'

# Set up an endpoint "/drive" to serve static files
sudo bash -c 'cat <<EOF > /etc/nginx/sites-available/drive
server {
    listen 80;
    server_name jamilali.rf.gd;

    location /drive {
        alias /srv;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        auth_basic "Restricted Content";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
EOF'

# Enable the "/drive" endpoint
sudo ln -s /etc/nginx/sites-available/drive /etc/nginx/sites-enabled/drive

# Add basic authentication to "/drive" endpoint
sudo htpasswd -c /etc/nginx/.htpasswd jamila
# Enter the desired password when prompted

# Restart Nginx service
sudo systemctl restart nginx

# Commit changes to the Git repository
cd ~/step_project_2
git add .
git commit -m "Added Nginx installation and configuration files"
