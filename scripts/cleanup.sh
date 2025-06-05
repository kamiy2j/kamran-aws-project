#!/bin/bash

# =======================================================
# AWS DevOps Infrastructure Cleanup Script
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
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -d "terraform" ]; then
        print_error "Please run this script from the project root directory."
        exit 1
    fi
    
    # Check if Terraform state exists
    if [ ! -f "terraform/terraform.tfstate" ] && [ ! -f "terraform/.terraform/terraform.tfstate" ]; then
        print_warning "No Terraform state found. Infrastructure might already be destroyed."
        exit 0
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to show current infrastructure
show_current_infrastructure() {
    print_status "Showing current infrastructure..."
    
    cd terraform
    
    # Show current state
    print_status "Current Terraform state:"
    terraform show -no-color | head -20
    
    echo ""
    print_status "Current resources:"
    terraform state list
    
    cd ..
}

# Function to confirm destruction
confirm_destruction() {
    echo ""
    print_warning "⚠️  WARNING: This will destroy ALL infrastructure resources!"
    print_warning "This includes:"
    echo "   • EC2 instances and Auto Scaling Groups"
    echo "   • RDS databases (with all data)"
    echo "   • Load Balancers and Target Groups"
    echo "   • VPC and networking components"
    echo "   • Route53 records"
    echo "   • SSL certificates"
    echo ""
    print_error "💥 THIS ACTION CANNOT BE UNDONE!"
    echo ""
    
    # Multiple confirmations for safety
    print_warning "Type 'yes' to confirm destruction:"
    read -r response1
    
    if [ "$response1" != "yes" ]; then
        print_status "Cleanup cancelled."
        exit 0
    fi
    
    print_warning "Are you absolutely sure? Type 'destroy' to confirm:"
    read -r response2
    
    if [ "$response2" != "destroy" ]; then
        print_status "Cleanup cancelled."
        exit 0
    fi
    
    print_status "Proceeding with infrastructure destruction..."
}

# Function to destroy infrastructure
destroy_infrastructure() {
    print_status "Destroying infrastructure..."
    
    cd terraform
    
    # Show destruction plan
    print_status "Generating destruction plan..."
    terraform plan -destroy -out=destroy.tfplan
    
    # Apply destruction
    print_status "Destroying resources..."
    terraform apply destroy.tfplan
    
    # Clean up plan files
    rm -f destroy.tfplan tfplan
    
    cd ..
    print_success "Infrastructure destruction completed!"
}

# Function to verify cleanup
verify_cleanup() {
    print_status "Verifying cleanup..."
    
    cd terraform
    
    # Check if any resources remain
    REMAINING_RESOURCES=$(terraform state list | wc -l)
    
    if [ "$REMAINING_RESOURCES" -eq 0 ]; then
        print_success "All resources have been successfully destroyed!"
    else
        print_warning "Some resources might still exist:"
        terraform state list
        print_warning "You may need to check AWS Console for any remaining resources."
    fi
    
    cd ..
}

# Function to clean up local files
cleanup_local_files() {
    print_status "Cleaning up local files..."
    
    cd terraform
    
    # Remove state backup files
    rm -f terraform.tfstate.backup*
    
    # Remove plan files
    rm -f *.tfplan
    
    # Keep .terraform directory as it contains provider cache
    # Users can run 'terraform init' again if needed
    
    cd ..
    
    print_success "Local cleanup completed!"
}

# Function to show post-cleanup info
show_post_cleanup_info() {
    echo ""
    print_success "🧹 Cleanup completed successfully!"
    echo ""
    print_status "What was cleaned up:"
    echo "✅ All AWS infrastructure resources destroyed"
    echo "✅ Terraform state cleaned"
    echo "✅ Local temporary files removed"
    echo ""
    print_status "Next steps:"
    echo "• Check AWS Console to verify all resources are gone"
    echo "• Review AWS billing to ensure no unexpected charges"
    echo "• Keep your code for future deployments"
    echo ""
    print_success "💰 You should no longer be charged for these AWS resources!"
}

# Main cleanup function
main() {
    echo ""
    print_status "🧹 AWS DevOps Infrastructure Cleanup"
    print_status "====================================="
    echo ""
    
    # Record start time
    START_TIME=$(date +%s)
    
    # Run cleanup steps
    check_prerequisites
    show_current_infrastructure
    confirm_destruction
    destroy_infrastructure
    verify_cleanup
    cleanup_local_files
    show_post_cleanup_info
    
    # Calculate cleanup time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    print_success "Total cleanup time: ${DURATION} seconds"
}

# Handle Ctrl+C gracefully
trap 'echo ""; print_warning "Cleanup interrupted by user."; exit 1' INT

# Run main function
main "$@"