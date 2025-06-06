#!/bin/bash

# Enhanced logging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== User Data Script Started at $(date) ==="

# Update system first
echo "Updating system..."
sudo dnf update -y

# Install basic packages (AL2023 approach)
echo "Installing base packages..."
sudo dnf install -y git curl wget

# Install Docker (AL2023 specific)
echo "Installing Docker..."
sudo dnf install -y docker
sudo systemctl enable docker
sudo systemctl start docker

# Install nginx
echo "Installing nginx..."
sudo dnf install -y nginx
sudo systemctl enable nginx

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

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

git clone ${github_repo} app
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to clone GitHub repository"
    exit 1
fi

# Set proper ownership
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
sudo -u ec2-user /usr/local/bin/docker-compose up -d

# Wait for containers to start
echo "Waiting for containers to initialize..."
sleep 90

# Configure Nginx as reverse proxy
echo "Configuring Nginx..."
cat <<EOF | sudo tee /etc/nginx/conf.d/app.conf
server {
    listen 80 default_server;
    server_name _;

    # Health check endpoint
    location /health {
        proxy_pass http://127.0.0.1:5000/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        access_log off;
    }

    # API endpoints
    location /api/ {
        proxy_pass http://127.0.0.1:5000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Frontend (default location)
    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Remove default nginx config
sudo rm -f /etc/nginx/conf.d/default.conf /etc/nginx/sites-enabled/default 2>/dev/null

# Start nginx
sudo systemctl start nginx

# Verify services
echo "=== Final Status Check ==="
echo "Nginx status: $(sudo systemctl is-active nginx)"
echo "Docker status: $(sudo systemctl is-active docker)"
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
        echo "Health check attempt $i failed, retrying..."
        sleep 15
    fi
done

echo "=== User Data Script Completed at $(date) ==="