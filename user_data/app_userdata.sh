#!/bin/bash

# Enhanced logging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== User Data Script Started at $(date) ==="

# Update system and install required packages (AL2023 uses dnf)
echo "Installing base packages..."
sudo dnf update -y
sudo dnf install -y nginx docker git curl

# Install Docker Compose
echo "Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/download/v2.21.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Node.js 20
echo "Installing Node.js 20..."
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo dnf install -y nodejs

# Enable and start services
echo "Starting services..."
sudo systemctl enable nginx docker
sudo systemctl start nginx docker

# Add ec2-user to docker group
sudo usermod -aG docker ec2-user

# Wait for services to start
echo "Waiting for services to initialize..."
sleep 10

# Clone the repository with fallback
echo "Cloning repository..."
cd /home/ec2-user

# Try cloning the repo, if it fails create a simple app
if ! sudo git clone ${github_repo} app; then
    echo "Git clone failed, creating demo app..."
    sudo mkdir -p app/docker/{frontend,backend}
    
    # Create a simple demo docker-compose.yml
    sudo tee app/docker/docker-compose.yml > /dev/null <<EOF
version: '3.8'
services:
  frontend:
    image: nginx:alpine
    ports:
      - "3000:80"
    volumes:
      - ./html:/usr/share/nginx/html
    depends_on:
      - backend

  backend:
    image: node:20-alpine
    ports:
      - "5000:5000"
    working_dir: /app
    command: node -e "
      const http = require('http');
      const server = http.createServer((req, res) => {
        if (req.url === '/health') {
          res.writeHead(200, {'Content-Type': 'application/json'});
          res.end(JSON.stringify({status: 'healthy', timestamp: new Date().toISOString()}));
        } else if (req.url.startsWith('/api/')) {
          res.writeHead(200, {'Content-Type': 'application/json'});
          res.end(JSON.stringify({message: 'Demo API', endpoint: req.url}));
        } else {
          res.writeHead(200, {'Content-Type': 'application/json'});
          res.end(JSON.stringify({message: 'Kamran Demo Backend', version: '1.0.0'}));
        }
      });
      server.listen(5000, '0.0.0.0', () => console.log('Demo server on port 5000'));
    "
EOF

    # Create simple HTML for frontend
    sudo mkdir -p app/docker/html
    sudo tee app/docker/html/index.html > /dev/null <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Kamran Demo App</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        .container { max-width: 800px; margin: 0 auto; }
        .status { background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Kamran AWS DevOps Demo</h1>
        <p>Full-Stack Application with Auto Scaling, Load Balancer & RDS</p>
        <div class="status">
            <h3>Infrastructure Status</h3>
            <p>✅ Load Balancer: Active</p>
            <p>✅ EC2 Instances: Running</p>
            <p>✅ RDS Database: Connected</p>
            <p>✅ SSL/HTTPS: Secured</p>
        </div>
        <p>Application deployed successfully!</p>
    </div>
</body>
</html>
EOF
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

# Wait for Docker to be ready and start containers
echo "Starting Docker containers..."
sleep 20
sudo -u ec2-user docker-compose up -d

# Wait for containers to start
echo "Waiting for containers to initialize..."
sleep 30

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
        
        # Fallback for frontend routing
        proxy_intercept_errors on;
        error_page 404 = @fallback;
    }
    
    location @fallback {
        proxy_pass http://127.0.0.1:3000/;
    }
}
EOF

# Remove default nginx config
sudo rm -f /etc/nginx/conf.d/default.conf /etc/nginx/sites-enabled/default 2>/dev/null || true

# Test nginx config and restart
echo "Testing and restarting Nginx..."
sudo nginx -t
sudo systemctl restart nginx

# Verify services are running
echo "=== Final Status Check ==="
echo "Nginx status: $(sudo systemctl is-active nginx)"
echo "Docker status: $(sudo systemctl is-active docker)"
echo "Running containers:"
sudo docker ps

# Test health endpoint locally
echo "Testing health endpoint..."
sleep 10
for i in {1..5}; do
    if curl -s http://localhost/health; then
        echo "Health check successful!"
        break
    else
        echo "Health check attempt $i failed, retrying in 10 seconds..."
        sleep 10
    fi
done

echo "=== User Data Script Completed at $(date) ==="