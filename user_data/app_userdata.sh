#!/bin/bash

exec > >(tee /var/log/user-data.log) 2>&1
echo "=== User Data Script Started at $$(date) ==="

# Install packages
sudo dnf update -y
sudo dnf install -y nginx docker git
sudo systemctl enable nginx docker
sudo systemctl start nginx docker
sudo usermod -aG docker ec2-user

# Create swap file for t2.micro (1GB instance)
echo "Creating swap space..."
sudo dd if=/dev/zero of=/swapfile bs=1M count=1024
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
EOF

# Clear Docker space
sudo docker system prune -af

# Build containers sequentially to reduce memory usage
echo "Building backend..."
sudo -u ec2-user docker build -t app-backend ./backend
sudo docker image prune -f

echo "Building frontend..."
sudo -u ec2-user docker build -t app-frontend ./frontend
sudo docker image prune -f

# Run containers
echo "Starting containers..."
sudo -u ec2-user docker run -d --name backend -p 5000:5000 --env-file .env --restart unless-stopped app-backend
sleep 10
sudo -u ec2-user docker run -d --name frontend -p 3000:3000 --restart unless-stopped app-frontend

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
sudo docker container prune -f

sleep 30
curl localhost/health
echo "=== Completed at $$(date) ==="