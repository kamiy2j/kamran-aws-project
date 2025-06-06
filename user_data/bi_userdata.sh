#!/bin/bash

# Enhanced logging
exec > >(tee /var/log/user-data.log) 2>&1
echo "=== BI Tool User Data Script Started at $(date) ==="

# Update system and install required packages (AL2023 uses dnf)
echo "Installing packages..."
sudo dnf update -y
sudo dnf install -y docker curl

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
  -e JAVA_OPTS="-Xmx512m" \
  metabase/metabase:latest

# Wait for Metabase to start
echo "Waiting for Metabase to start..."
sleep 60

# Test if Metabase is responding
echo "Testing Metabase..."
for i in {1..10}; do
    if curl -s http://localhost:5000/api/health 2>/dev/null; then
        echo "Metabase is running!"
        break
    else
        echo "Waiting for Metabase... attempt $i"
        sleep 30
    fi
done

# Show final status
echo "=== Final Status ==="
echo "Docker status: $(sudo systemctl is-active docker)"
echo "Running containers:"
sudo docker ps

echo "=== BI Tool User Data Script Completed at $(date) ==="