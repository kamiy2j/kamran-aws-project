#!/bin/bash

# Enhanced logging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== BI Tool User Data Script Started at $(date) ==="

# Update system and install required packages
echo "Installing packages..."
sudo dnf update -y
sudo dnf install -y docker nginx python3-pip
sudo dnf install -y nginx docker git

# Install certbot
sudo pip3 install certbot certbot-nginx

# Create swap
sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab

# Enable and start Docker
echo "Starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ec2-user

# Wait for Docker to be ready
echo "Waiting for Docker to initialize..."
sleep 30

echo "Running Metabase container..."
# Run Metabase container
sudo docker run -d \
  --name metabase \
  --restart unless-stopped \
  -p 5000:3000 \
  -e MB_DB_TYPE=h2 \
  -e JAVA_OPTS="-Xmx256m -Xms128m" \
  metabase/metabase:latest

# Wait for Metabase to start
echo "Waiting for Metabase to start..."
sleep 60

# Wait for Metabase to be fully ready
echo "Waiting for Metabase to fully initialize..."
for i in {1..20}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:5000/api/health 2>/dev/null || echo "000")
    if [[ "$HTTP_CODE" == "200" ]]; then
        echo "Metabase is ready!"
        break
    else
        echo "Waiting... attempt $i (HTTP: $HTTP_CODE)"
        sleep 30
    fi
done

# Now configure nginx after Metabase is ready
echo "Configuring nginx..."
sudo systemctl enable nginx
sudo systemctl start nginx

# Remove default config
sudo rm -f /etc/nginx/conf.d/default.conf
sudo rm -f /etc/nginx/sites-enabled/default 2>/dev/null

# Configure nginx proxy
sudo tee /etc/nginx/conf.d/bi.conf > /dev/null << 'EOF'
server {
    listen 80;
    server_name bi.kamranshahid.com;
    
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_buffering off;
    }
}
EOF

# Test and reload nginx
sudo nginx -t
sudo systemctl reload nginx

# Wait a bit more for everything to stabilize
sleep 30

# # GitHub Gist settings
# GITHUB_TOKEN=""  # Your GitHub personal access token with gist permissions
# GIST_ID="" # Existing gist ID if you have one, leave empty to create a new one

# # Function to backup certificates to GitHub gist
# backup_certificates() {
#     if [ -d "/etc/letsencrypt/live/bi.kamranshahid.com" ]; then
#         echo "Backing up certificates to GitHub gist..."
        
#         # Create tar archive of certificates
#         sudo tar -czf /tmp/certs_backup.tar.gz -C /etc/letsencrypt .
        
#         # Base64 encode for gist upload
#         CERT_DATA=$(base64 -w 0 /tmp/certs_backup.tar.gz)
        
#         # Update existing gist
#         curl -s -X PATCH \
#             -H "Authorization: token $GITHUB_TOKEN" \
#             -H "Content-Type: application/json" \
#             -d "{
#                 \"files\": {
#                     \"certificates.tar.gz.b64\": {
#                         \"content\": \"$CERT_DATA\"
#                     }
#                 }
#             }" \
#             https://api.github.com/gists/$GIST_ID
        
#         rm -f /tmp/certs_backup.tar.gz
#         echo "Certificates backed up successfully"
#     fi
# }

# # Function to restore certificates from GitHub gist
# restore_certificates() {
#     echo "Checking for certificate backup..."
    
#     if [ -n "$GIST_ID" ]; then
#         # Download from existing gist
#         CERT_DATA=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
#             https://api.github.com/gists/$GIST_ID | \
#             grep -o '"content":"[^"]*"' | cut -d'"' -f4)
        
#         if [ -n "$CERT_DATA" ]; then
#             echo "Restoring certificates from backup..."
            
#             # Decode and extract
#             echo "$CERT_DATA" | base64 -d > /tmp/certs_restore.tar.gz
#             sudo mkdir -p /etc/letsencrypt
#             sudo tar -xzf /tmp/certs_restore.tar.gz -C /etc/letsencrypt
#             sudo chmod -R 600 /etc/letsencrypt
            
#             rm -f /tmp/certs_restore.tar.gz
#             echo "Certificates restored successfully"
#             return 0
#         fi
#     fi
    
#     echo "No certificate backup found"
#     return 1
# }

# # SSL Certificate handling
# echo "Checking for existing SSL certificate..."

# # Try to restore from backup first
# if restore_certificates; then
#     echo "Using restored certificates"
#     sudo certbot --nginx -d bi.kamranshahid.com --non-interactive --keep-until-expiring
# else
#     echo "No backup found, requesting new certificate..."
    
#     if sudo certbot --nginx -d bi.kamranshahid.com --non-interactive --agree-tos --email kamiy2j@gmail.com; then
#         echo "Certificate obtained successfully"
#         backup_certificates
#     else
#         echo "Failed to obtain certificate - rate limited"
#     fi
# fi

# Test database connectivity
echo "Testing database connectivity..."
timeout 10 bash -c "</dev/tcp/${pg_host}/5432" 2>/dev/null && echo "PostgreSQL reachable" || echo "PostgreSQL unreachable"
timeout 10 bash -c "</dev/tcp/${mysql_host}/3306" 2>/dev/null && echo "MySQL reachable" || echo "MySQL unreachable"

# Additional wait to ensure setup endpoint is ready
sleep 60

# Check if already setup
SETUP_RESPONSE=$(curl -s http://localhost:5000/api/session/properties 2>/dev/null || echo "")
SETUP_TOKEN=$(echo "$SETUP_RESPONSE" | grep -o '"setup-token":"[^"]*"' | cut -d'"' -f4)

# Also try alternative token name
if [ -z "$SETUP_TOKEN" ] || [ "$SETUP_TOKEN" == "null" ]; then
    SETUP_TOKEN=$(echo "$SETUP_RESPONSE" | grep -o '"setup_token":"[^"]*"' | cut -d'"' -f4)
fi

if [ "$SETUP_TOKEN" != "null" ] && [ -n "$SETUP_TOKEN" ]; then
    echo "Setting up Metabase admin user..."
    
    # Setup with just user creation (no database in initial setup)
    SETUP_RESULT=$(curl -s -X POST http://localhost:5000/api/setup \
    -H "Content-Type: application/json" \
    -d '{
        "token": "'$SETUP_TOKEN'",
        "user": {
        "first_name": "Kamran",
        "last_name": "Shahid", 
        "email": "kamiy2j@gmail.com",
        "password": "Password123!"
        },
        "prefs": {
        "site_name": "Metabase BI Tool",
        "site_locale": "en"
        }
    }')
    
    echo "Setup result: $SETUP_RESULT"
    sleep 15
    
    # Login to get session
    echo "Logging in to add databases..."
    SESSION_RESPONSE=$(curl -s -X POST http://localhost:5000/api/session \
      -H "Content-Type: application/json" \
      -d '{"username": "kamiy2j@gmail.com", "password": "Password123!"}')
    
    SESSION_ID=$(echo "$SESSION_RESPONSE" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$SESSION_ID" ] && [ "$SESSION_ID" != "null" ]; then
        echo "Successfully logged in with session: $SESSION_ID"
        
        # Add PostgreSQL database
        echo "Adding PostgreSQL database..."
        PG_RESULT=$(curl -s -X POST http://localhost:5000/api/database \
          -H "Content-Type: application/json" \
          -H "X-Metabase-Session: $SESSION_ID" \
          -d '{
            "engine": "postgres",
            "name": "PostgreSQL Kamran",
            "details": {
              "host": "'${pg_host}'",
              "port": 5432,
              "dbname": "'${pg_database}'",
              "user": "'${pg_user}'",
              "password": "'${pg_password}'",
              "ssl": false
            }
          }')
        echo "PostgreSQL setup result: $PG_RESULT"
        
        sleep 5
        
        # Add MySQL database
        echo "Adding MySQL database..."
        MYSQL_RESULT=$(curl -s -X POST http://localhost:5000/api/database \
          -H "Content-Type: application/json" \
          -H "X-Metabase-Session: $SESSION_ID" \
          -d '{
            "engine": "mysql",
            "name": "MySQL Kamran",
            "details": {
              "host": "'${mysql_host}'",
              "port": 3306,
              "dbname": "'${mysql_database}'",
              "user": "'${mysql_user}'",
              "password": "'${mysql_password}'",
              "ssl": false,
              "additional-options": "useSSL=false"
            }
          }')
        echo "MySQL setup result: $MYSQL_RESULT"
        
        echo "Metabase setup completed!"
    else
        echo "Failed to login. Session response: $SESSION_RESPONSE"
    fi
else
    echo "Metabase already configured or setup token not available"
    echo "Setup response: $SETUP_RESPONSE"
fi

# Show final status
echo "=== Final Status ==="
echo "Docker status: $(sudo systemctl is-active docker)"
echo "Nginx status: $(sudo systemctl is-active nginx)"
echo "Running containers:"
sudo docker ps

echo "=== BI Tool User Data Script Completed at $(date) ==="