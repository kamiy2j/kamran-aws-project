#!/bin/bash

# Update system and install required packages
sudo yum update -y
sudo yum install -y nginx docker git

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Node.js 20
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo yum install -y nodejs

# Enable and start services
sudo systemctl enable nginx docker
sudo systemctl start nginx docker

# Add ec2-user to docker group
sudo usermod -aG docker ec2-user

# Wait for services to start
sleep 10

# Clone the repository
cd /home/ec2-user
sudo git clone ${github_repo} app || {
    echo "Git clone failed, creating placeholder app"
    sudo mkdir -p app/docker
    sudo chown -R ec2-user:ec2-user app
    exit 0
}
sudo chown -R ec2-user:ec2-user app

# Navigate to docker directory
cd /home/ec2-user/app/docker

# Create environment file for Docker Compose
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
EOF

# Wait for Docker to be ready
sleep 30

# Build and run the application
sudo -u ec2-user docker-compose up -d

# Wait for containers to start
sleep 60

# Configure Nginx as reverse proxy
cat <<EOF | sudo tee /etc/nginx/conf.d/app.conf
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

# Remove default nginx config
sudo rm -f /etc/nginx/conf.d/default.conf

# Restart Nginx
sudo systemctl restart nginx

# Log status for debugging
echo "=== Docker Status ===" >> /var/log/user-data.log
sudo docker ps >> /var/log/user-data.log
echo "=== Docker Logs ===" >> /var/log/user-data.log
sudo docker-compose logs >> /var/log/user-data.log