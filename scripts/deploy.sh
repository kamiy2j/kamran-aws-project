#!/bin/bash

# =======================================================
# AWS DevOps Infrastructure Deployment Script
# =======================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if AWS CLI is installed and configured
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed. Please install it first."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured. Run 'aws configure' first."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -d "terraform" ]; then
        print_error "Please run this script from the project root directory."
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to validate Terraform configuration
validate_terraform() {
    print_status "Validating Terraform configuration..."
    
    cd terraform
    
    # Initialize Terraform
    print_status "Initializing Terraform..."
    terraform init
    
    # Validate configuration
    print_status "Validating Terraform configuration..."
    terraform validate
    
    # Format check
    print_status "Checking Terraform formatting..."
    terraform fmt -check || {
        print_warning "Terraform files need formatting. Running 'terraform fmt'..."
        terraform fmt
    }
    
    cd ..
    print_success "Terraform validation completed!"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_status "Starting infrastructure deployment..."
    
    cd terraform
    
    # Show deployment plan
    print_status "Generating deployment plan..."
    terraform plan -out=tfplan
    
    # Ask for confirmation
    echo ""
    print_warning "Review the plan above. Do you want to proceed with deployment? (y/N)"
    read -r response
    
    case "$response" in
        [yY][eE][sS]|[yY]) 
            print_status "Deploying infrastructure..."
            terraform apply tfplan
            ;;
        *)
            print_warning "Deployment cancelled by user."
            exit 0
            ;;
    esac
    
    cd ..
    print_success "Infrastructure deployment completed!"
}

# Function to show deployment outputs
show_outputs() {
    print_status "Retrieving deployment outputs..."
    
    cd terraform
    
    echo ""
    print_success "=== DEPLOYMENT OUTPUTS ==="
    terraform output
    
    echo ""
    print_success "=== ACCESS URLS ==="
    APP_URL=$(terraform output -raw app_url 2>/dev/null || echo "Not available")
    BI_URL=$(terraform output -raw bi_tool_url 2>/dev/null || echo "Not available")
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "Not available")
    
    echo "Application URL: $APP_URL"
    echo "BI Tool URL: $BI_URL"
    echo "Load Balancer DNS: $ALB_DNS"
    
    cd ..
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    cd terraform
    
    # Get ALB DNS name
    ALB_DNS=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
    
    if [ -n "$ALB_DNS" ]; then
        print_status "Testing application health..."
        
        # Wait a bit for services to start
        sleep 30
        
        # Test health endpoint
        if curl -s "http://$ALB_DNS/health" > /dev/null; then
            print_success "Application is responding!"
        else
            print_warning "Application might still be starting up. Check back in a few minutes."
        fi
    fi
    
    cd ..
}

# Main deployment function
main() {
    echo ""
    print_status "🚀 AWS DevOps Infrastructure Deployment"
    print_status "========================================"
    echo ""
    
    # Record start time
    START_TIME=$(date +%s)
    
    # Run deployment steps
    check_prerequisites
    validate_terraform
    deploy_infrastructure
    show_outputs
    verify_deployment
    
    # Calculate deployment time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    print_success "🎉 Deployment completed successfully!"
    print_success "Total deployment time: ${DURATION} seconds"
    echo ""
    print_status "Next steps:"
    echo "1. Wait 5-10 minutes for all services to fully start"
    echo "2. Test the application URLs shown above"
    echo "3. Set up SSH tunnels for database access (see scripts/setup-tunnel.sh)"
    echo "4. Configure BI tool dashboards"
    echo ""
    print_warning "💰 Remember to run './scripts/cleanup.sh' when done to avoid AWS charges!"
}

# Run main function
main "$@"