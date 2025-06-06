#!/bin/bash

# Enhanced logging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== BI Tool User Data Script Started at $(date) ==="

# Update system and install required packages (AL2023 uses dnf)
echo "Installing packages..."
sudo dnf update -y
sudo dnf install -y docker

sudo dd if=/dev/zero of=/swapfile bs=1M count=2048
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Enable and start Docker
echo "Starting Docker..."
sudo systemctl enable docker
sudo systemctl start docker

# Add ec2-user to docker group
sudo usermod -aG docker ec2-user

# Wait for Docker to be ready
echo "Waiting for Docker to initialize..."
sleep 30

# Extract database host (remove port if present)
DB_HOST_CLEAN=$(echo "${db_host}" | cut -d: -f1)

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

# Additional wait to ensure setup endpoint is ready
sleep 60

# Test database connectivity
echo "Testing database connectivity..."
timeout 10 bash -c "</dev/tcp/$DB_HOST_CLEAN/5432" 2>/dev/null && echo "PostgreSQL reachable" || echo "PostgreSQL unreachable"

# Check if already setup
SETUP_RESPONSE=$(curl -s http://localhost:5000/api/session/properties 2>/dev/null || echo "")
SETUP_TOKEN=$(echo "$SETUP_RESPONSE" | grep -o '"setup-token":"[^"]*"' | cut -d'"' -f4)

# Also try alternative token name
if [ -z "$SETUP_TOKEN" ] || [ "$SETUP_TOKEN" == "null" ]; then
    SETUP_TOKEN=$(echo "$SETUP_RESPONSE" | grep -o '"setup_token":"[^"]*"' | cut -d'"' -f4)
fi

if [ "$SETUP_TOKEN" != "null" ] && [ -n "$SETUP_TOKEN" ]; then
    echo "Setting up Metabase admin and databases..."
    
    # Setup with actual token
    curl -X POST http://localhost:5000/api/setup \
      -H "Content-Type: application/json" \
      -d '{
        "token": "'$SETUP_TOKEN'",
        "user": {
          "first_name": "Kamran",
          "last_name": "Shahid", 
          "email": "kamiy2j@gmail.com",
          "password": "Password123!"
        },
        "database": {
          "engine": "postgres",
          "name": "PostgreSQL",
          "details": {
            "host": "'$DB_HOST_CLEAN'",
            "port": 5432,
            "dbname": "'${pg_database}'",
            "user": "'${pg_user}'",
            "password": "'${pg_password}'"
          }
        }
      }'
    
    sleep 15
    
    # Login and add MySQL
    SESSION_ID=$(curl -s -X POST http://localhost:5000/api/session \
      -H "Content-Type: application/json" \
      -d '{"username": "kamiy2j@gmail.com", "password": "Password123!"}' | \
      grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$SESSION_ID" ]; then
        curl -X POST http://localhost:5000/api/database \
          -H "Content-Type: application/json" \
          -H "X-Metabase-Session: $SESSION_ID" \
          -d '{
            "engine": "mysql",
            "name": "MySQL",
            "details": {
              "host": "'${mysql_host}'",
              "port": 3306,
              "dbname": "'${mysql_database}'",
              "user": "'${mysql_user}'",
              "password": "'${mysql_password}'"
            }
          }'
        echo "Metabase setup completed!"
    fi
else
    echo "Metabase already configured or setup token not available"
fi

# Show final status
echo "=== Final Status ==="
echo "Docker status: $(sudo systemctl is-active docker)"
echo "Running containers:"
sudo docker ps

echo "=== BI Tool User Data Script Completed at $(date) ==="