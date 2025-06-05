#!/bin/bash

# Update system and install required packages
sudo yum update -y
sudo yum install -y docker git

# Install Node.js 20
curl -fsSL https://rpm.nodesource.com/setup_20.x | sudo bash -
sudo yum install -y nodejs

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add ec2-user to docker group
sudo usermod -aG docker ec2-user

# Create directory for Metabase
sudo mkdir -p /opt/metabase
sudo chown ec2-user:ec2-user /opt/metabase

# Wait for Docker to be ready
sleep 30

# Run Metabase container
sudo docker run -d \
  --name metabase \
  -p 5000:3000 \
  -e MB_DB_TYPE=postgres \
  -e MB_DB_DBNAME=devopsdb \
  -e MB_DB_PORT=5432 \
  -e MB_DB_USER=${db_username} \
  -e MB_DB_PASS=${db_password} \
  -e MB_DB_HOST=${db_host} \
  metabase/metabase

# Install PostgreSQL client for debugging
sudo yum install -y postgresql