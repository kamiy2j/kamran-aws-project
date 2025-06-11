# AWS Scalable Infrastructure with Terraform

A comprehensive AWS infrastructure project implementing auto-scaling EC2 instances, containerized applications, RDS databases, load balancing, and business intelligence tools using Terraform.

## 🏗️ Architecture Overview

This project deploys a scalable, secure, and containerized AWS environment featuring:

- **Auto Scaling Group** with 3 EC2 instances running Nginx, Docker, and Node.js 20
- **RDS Instances** (MySQL + PostgreSQL) in private subnets
- **Application Load Balancer** with HTTPS support
- **Multi-stage Dockerized Applications** (Frontend + Backend)
- **Business Intelligence Tool** (Redash/Metabase)
- **Domain & SSL Configuration** with Let's Encrypt/AWS ACM
- **Secure Database Access** via SSH tunneling

## 📋 Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Domain name for SSL configuration
- SSH key pair for EC2 access

## 🚀 Quick Start

### 1. Clone and Configure

```bash
git clone https://github.com/kamiy2j/kamran-aws-project
cd kamran-aws-project
```

### 2. Set Variables

Update `variables.tf` with your specific values:
- Domain name
- SSH key name
- Preferred AWS region
- Database credentials

### 3. Deploy Infrastructure

```bash
terraform init
terraform plan
terraform apply
```

### 4. Configure Applications

```bash
# Copy environment variables for Docker
cp docker/.env.example docker/.env
# Update with your database connection details
```

## 📁 Project Structure

```
kamran-aws-project/
├── terraform/
│   ├── main.tf              # Main configuration and providers
│   ├── vpc.tf               # VPC, subnets, and networking
│   ├── ec2.tf               # Auto Scaling Group and Launch Template
│   ├── rds.tf               # MySQL and PostgreSQL databases
│   ├── alb.tf               # Application Load Balancer
│   ├── target_group.tf      # Load balancer target groups
│   ├── security_groups.tf   # Security group configurations
│   ├── route53.tf           # DNS and domain configuration
│   ├── variables.tf         # Input variables
│   └── outputs.tf           # Output values
├── docker/
│   ├── docker-compose.yml   # Multi-container setup
│   ├── .env.example         # Environment variables template
│   ├── frontend/            # React frontend application
│   │   ├── Dockerfile       # Multi-stage frontend build
│   │   ├── nginx.conf       # Nginx configuration
│   │   └── src/             # React source code
│   └── backend/             # Node.js backend API
│       ├── Dockerfile       # Multi-stage backend build
│       ├── server.js        # Express server
│       └── package.json     # Node.js dependencies
└── user_data/
    ├── app_userdata.sh      # EC2 setup script for app instances
    └── bi_userdata.sh       # EC2 setup script for BI instance
```

## 🔧 Infrastructure Components

### Networking
- **VPC** with public and private subnets across multiple AZs
- **Internet Gateway** for public subnet access
- **NAT Gateway** for private subnet outbound traffic
- **Route Tables** for proper traffic routing

### Compute
- **Auto Scaling Group** with 3 EC2 instances
- **Launch Template** with user data for automated setup
- **Application Load Balancer** for traffic distribution
- **Target Groups** for health checking

### Database
- **RDS MySQL** instance in private subnet
- **RDS PostgreSQL** instance in private subnet
- **DB Subnet Groups** for multi-AZ deployment
- **Security Groups** restricting access to EC2 instances only

### Security
- **Security Groups** with least privilege access
- **SSH Key Pairs** for secure instance access
- **SSL/TLS Certificates** via AWS ACM or Let's Encrypt
- **Private Subnets** for database isolation

## 🐳 Application Deployment

### Frontend (React)
- Multi-stage Docker build for optimized production images
- Nginx reverse proxy for static file serving
- Responsive web interface

### Backend (Node.js)
- Express.js API server
- Database connectivity to RDS instances
- Health check endpoints for load balancer

### BI Tool (Redash/Metabase)
- Containerized deployment on dedicated EC2 instance
- Connected to RDS databases
- Real-time dashboard updates

## 🔐 Database Access

### SSH Tunneling Setup

```bash
# Create SSH tunnel to MySQL
ssh -i your-key -L 3306:mysql-endpoint:3306 ec2-user@ec2-public-ip

# Create SSH tunnel to PostgreSQL
ssh -i your-key -L 5432:postgres-endpoint:5432 ec2-user@ec2-public-ip
```

### DBeaver Connection
1. Create new connection
2. Use localhost with tunneled ports
3. Configure database credentials

## 🌐 Domain & SSL Configuration

- **Route53** DNS configuration
- **ACM Certificate** for HTTPS
- **Load Balancer** HTTPS listener
- **HTTP to HTTPS** redirect

## 📊 Features Implemented

✅ **Auto Scaling EC2 Instances**
- Nginx, Docker, Node.js 20 installed via user data
- Health checks and auto-recovery

✅ **Secure RDS Deployment**
- Private subnet placement
- Security group restrictions
- Multi-AZ availability

✅ **Load Balancer with HTTPS**
- SSL termination
- Health monitoring
- Traffic distribution

✅ **Containerized Applications**
- Multi-stage Docker builds
- Frontend and backend separation
- Production-optimized images

✅ **Business Intelligence**
- BI tool deployment
- Database connectivity
- Real-time dashboards

✅ **Security Best Practices**
- Private database subnets
- SSH tunnel access
- SSL/TLS encryption

## 🔨 Usage Instructions

### Accessing Applications

1. **Web Application**: `https://your-domain.com`
2. **BI Dashboard**: `https://bi.your-domain.com`
3. **Database Access**: Via SSH tunnel through EC2 instances

### Monitoring and Maintenance

- Check Auto Scaling Group health in AWS Console
- Monitor RDS performance metrics
- Review load balancer target health
- Update SSL certificates before expiration

## 🧪 Testing

### Application Testing
```bash
# Test frontend
curl https://your-domain.com

# Test API endpoints
curl https://your-domain.com/api/health

# Test database connectivity
# Via SSH tunnel and DBeaver/mysql client
```

### Infrastructure Validation
```bash
# Verify resources
terraform plan
terraform output

# Check security groups
aws ec2 describe-security-groups

# Validate SSL certificate
openssl s_client -connect your-domain.com:443
```

## 🚨 Important Notes

- **Database Security**: RDS instances are in private subnets with no public access
- **SSL Required**: All traffic is encrypted with HTTPS
- **Scaling**: Auto Scaling Group automatically manages instance count
- **Backups**: RDS automated backups are enabled
- **Monitoring**: CloudWatch monitoring is configured

## 🔧 Troubleshooting

### Common Issues

1. **SSL Certificate Issues**
   - Verify domain ownership
   - Check ACM certificate status
   - Ensure Route53 records are correct

2. **Database Connection Problems**
   - Verify SSH tunnel is active
   - Check security group rules
   - Confirm RDS endpoint accessibility

3. **Application Deployment Issues**
   - Check user data script execution
   - Verify Docker container status
   - Review EC2 instance logs


## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

**Created by**: Kamran Shahid
**Project Type**: AWS Infrastructure with Terraform  
**Last Updated**: June 2025
