#!/bin/bash

# Enhanced logging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== User Data Script Started at $$(date) ==="

# Update system and install packages in one command (AL2023 approach)
echo "Installing packages..."
sudo dnf update -y
sudo dnf install -y nginx docker git wget unzip

# Enable and start services
echo "Starting services..."
sudo systemctl enable nginx docker
sudo systemctl start nginx docker

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o /usr/bin/docker-compose && sudo chmod 755 /usr/bin/docker-compose && docker-compose --version 


# Install Node.js 20
echo "Installing Node.js 20..."
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs

# Add ec2-user to docker group
sudo usermod -aG docker ec2-user

# Verify installations
echo "Verifying installations..."
docker --version || echo "Docker installation failed"
nginx -v || echo "Nginx installation failed"
node --version || echo "Node installation failed"
git --version || echo "Git installation failed"

# Wait for Docker to start
echo "Waiting for Docker to start..."
sleep 15

# Clone the repository
echo "Cloning repository..."
cd /home/ec2-user
sudo git clone ${github_repo} app
sudo chown -R ec2-user:ec2-user app

# Navigate to docker directory
cd /home/ec2-user/app/docker

# Create environment file for Docker Compose
echo "Creating environment file..."
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

# Start Docker containers
echo "Starting Docker containers..."
sleep 10
cd /home/ec2-user/app/docker
sudo -u ec2-user /usr/local/bin/docker-compose up -d

# Wait for containers to start
echo "Waiting for containers to initialize..."
sleep 90

# Configure Nginx as reverse proxy
echo "Configuring Nginx..."
sudo tee /etc/nginx/conf.d/app.conf > /dev/null << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        access_log off;
    }

    # API endpoints
    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Frontend (default location)
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXEOF

# Remove default nginx config
sudo rm -f /etc/nginx/conf.d/default.conf /etc/nginx/sites-enabled/default 2>/dev/null

# Restart nginx
sudo systemctl restart nginx

# Verify services
echo "=== Final Status Check ==="
echo "Nginx status: $$(sudo systemctl is-active nginx)"
echo "Docker status: $$(sudo systemctl is-active docker)"
echo "Running containers:"
sudo docker ps

# Test health endpoint
echo "Testing health endpoint..."
sleep 20
for i in {1..10}; do
    if curl -s http://localhost/health; then
        echo "Health check successful!"
        break
    else
        echo "Health check attempt $$i failed, retrying..."
        sleep 15
    fi
done

echo "=== User Data Script Completed at $$(date) ==="