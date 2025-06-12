#!/bin/bash

exec > >(tee /var/log/user-data.log) 2>&1
echo "=== User Data Script Started at $$(date) ==="

# Install packages (including docker-compose)
sudo dnf update -y
sudo dnf install -y nginx docker git
sudo systemctl enable nginx docker
sudo systemctl start nginx docker
sudo usermod -aG docker ec2-user

# Install docker-compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sudo dnf clean all
sudo rm -rf /var/cache/dnf/*

# Create swap file for t2.micro (1GB instance)
echo "Creating swap space..."
sudo dd if=/dev/zero of=/swapfile bs=1M count=512
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

sleep 15

# Clone repo
cd /home/ec2-user
sudo git clone ${github_repo} app
sudo chown -R ec2-user:ec2-user app
cd app/docker

# Get instance metadata
echo "Getting instance metadata..."
INSTANCE_ID=$(TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s) && curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)
echo "Instance ID: $INSTANCE_ID"

# Create .env
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

# Clear Docker space
sudo docker system prune -af

# Use docker-compose instead of manual commands
echo "Starting application with docker-compose..."
sudo -u ec2-user docker-compose up -d --build

# Wait for containers to be ready
sleep 30

# Configure Nginx
sudo tee /etc/nginx/conf.d/app.conf > /dev/null << 'EOF'
server {
    listen 80 default_server;
    server_name _;
    location /health { proxy_pass http://127.0.0.1:5000/health; }
    location /api/ { proxy_pass http://127.0.0.1:5000/api/; }
    location / { proxy_pass http://127.0.0.1:3000; }
}
EOF

sudo rm -f /etc/nginx/conf.d/default.conf
sudo systemctl restart nginx

# Final cleanup
sudo docker image prune -f

sleep 30
curl localhost/health
echo "=== Completed at $$(date) ==="