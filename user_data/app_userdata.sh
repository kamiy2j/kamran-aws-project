#!/bin/bash

exec > >(tee /var/log/user-data.log) 2>&1
echo "=== User Data Script Started at $(date) ==="

# 1) Install system packages
dnf update -y
dnf install -y nginx docker git
systemctl enable nginx docker
systemctl start nginx docker
usermod -aG docker ec2-user

# 2) Install docker-compose
curl -sSL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

dnf clean all
rm -rf /var/cache/dnf/*

# 3) Add swap (for t2.micro)
echo "Creating swap space..."
dd if=/dev/zero of=/swapfile bs=1M count=512
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab

sleep 15

# 4) Clone your repo & prepare docker-compose dir
cd /home/ec2-user
git clone ${github_repo} app
chown -R ec2-user:ec2-user app
cd app/docker

# 5) Fetch instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds:21600" -s)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" \
  -s http://169.254.169.254/latest/meta-data/instance-id)

# 6) Write .env & fix ownership
cat <<EOF > .env
PG_HOST=${pg_host}
PG_PORT=5432
PG_DATABASE=${pg_database}
PG_USER=${pg_user}
PG_PASSWORD=${pg_password}
MYSQL_HOST=${mysql_host}
MYSQL_PORT=3306
MYSQL_DATABASE=${mysql_database}
MYSQL_USER=${mysql_user}
MYSQL_PASSWORD=${mysql_password}
REACT_APP_API_URL=/api
EC2_INSTANCE_ID=$INSTANCE_ID
EOF

chown ec2-user:ec2-user .env

# 7) Prune old Docker artifacts
docker system prune -af

# 8) Start your stack
sudo -u ec2-user docker-compose up -d --build

# 9) Give containers a moment
sleep 30

# 10) Configure Nginx proxy
tee /etc/nginx/conf.d/app.conf > /dev/null << 'NGINX_EOF'
server {
    listen 80 default_server;
    server_name _;
    location /health { proxy_pass http://127.0.0.1:5000/health; }
    location /api/    { proxy_pass http://127.0.0.1:5000/api/; }
    location /        { proxy_pass http://127.0.0.1:3000; }
}
NGINX_EOF

# remove any other confs so only app.conf remains
rm -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/welcome.conf

# 11) Disable the built-in default server block in nginx.conf
sed -i '/^\s*server\s*{/,/^\s*}/ {/^\s*listen\s\+80;/s/^/#/}' /etc/nginx/nginx.conf
sed -i '/^\s*server\s*{/,/^\s*}/ {/^\s*listen\s\+\[::\]:80;/s/^/#/}' /etc/nginx/nginx.conf

# 12) Reload Nginx so only your app.conf serves port 80
nginx -s reload

# 13) Final cleanup & health check
docker image prune -f
docker container prune -f
sleep 10
curl -sf http://localhost/health && echo "App is up!" || echo "Health check failed."

echo "=== User Data Script Completed at $(date) ==="
