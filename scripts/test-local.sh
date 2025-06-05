#!/bin/bash

# =======================================================
# Local Docker Application Testing Script
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
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -d "docker" ]; then
        print_error "Please run this script from the project root directory."
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to build and start containers
start_containers() {
    print_status "Building and starting Docker containers..."
    
    cd docker
    
    # Stop any existing containers
    print_status "Stopping any existing containers..."
    docker-compose down 2>/dev/null || true
    
    # Build and start containers
    print_status "Building containers..."
    docker-compose build
    
    print_status "Starting containers..."
    docker-compose up -d
    
    cd ..
    print_success "Containers started successfully!"
}

# Function to wait for services
wait_for_services() {
    print_status "Waiting for services to start..."
    
    # Wait for backend to be ready
    print_status "Waiting for backend service..."
    for i in {1..30}; do
        if curl -s http://localhost:5000/health > /dev/null 2>&1; then
            print_success "Backend service is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            print_error "Backend service failed to start within 30 seconds"
            return 1
        fi
        sleep 1
        echo -n "."
    done
    
    # Wait for frontend to be ready
    print_status "Waiting for frontend service..."
    for i in {1..30}; do
        if curl -s http://localhost:3000 > /dev/null 2>&1; then
            print_success "Frontend service is ready!"
            break
        fi
        if [ $i -eq 30 ]; then
            print_error "Frontend service failed to start within 30 seconds"
            return 1
        fi
        sleep 1
        echo -n "."
    done
}

# Function to test application endpoints
test_endpoints() {
    print_status "Testing application endpoints..."
    
    # Test backend health
    print_status "Testing backend health endpoint..."
    HEALTH_RESPONSE=$(curl -s http://localhost:5000/health)
    if echo "$HEALTH_RESPONSE" | grep -q "healthy"; then
        print_success "✅ Backend health check passed"
    else
        print_error "❌ Backend health check failed"
        echo "Response: $HEALTH_RESPONSE"
    fi
    
    # Test frontend
    print_status "Testing frontend..."
    if curl -s http://localhost:3000 | grep -q "DevOps Demo"; then
        print_success "✅ Frontend is serving content"
    else
        print_warning "⚠️  Frontend might not be fully loaded"
    fi
    
    # Test API endpoints
    print_status "Testing API endpoints..."
    
    # Test users endpoint
    USERS_RESPONSE=$(curl -s http://localhost:5000/api/users)
    if echo "$USERS_RESPONSE" | grep -q "\[\]" || echo "$USERS_RESPONSE" | grep -q "id"; then
        print_success "✅ Users API endpoint working"
    else
        print_warning "⚠️  Users API might have issues"
        echo "Response: $USERS_RESPONSE"
    fi
    
    # Test stats endpoint
    STATS_RESPONSE=$(curl -s http://localhost:5000/api/stats)
    if echo "$STATS_RESPONSE" | grep -q "total_users"; then
        print_success "✅ Stats API endpoint working"
    else
        print_warning "⚠️  Stats API might have issues"
        echo "Response: $STATS_RESPONSE"
    fi
}

# Function to show container status
show_container_status() {
    print_status "Container status:"
    
    cd docker
    docker-compose ps
    cd ..
    
    print_status "Container logs (last 10 lines):"
    echo "=== Backend Logs ==="
    cd docker
    docker-compose logs --tail=10 backend
    echo ""
    echo "=== Frontend Logs ==="
    docker-compose logs --tail=10 frontend
    cd ..
}

# Function to show access information
show_access_info() {
    echo ""
    print_success "🎉 Local testing completed!"
    echo ""
    print_status "Access your application:"
    echo "🌐 Frontend: http://localhost:3000"
    echo "⚙️  Backend API: http://localhost:5000"
    echo "❤️  Health Check: http://localhost:5000/health"
    echo "👥 Users API: http://localhost:5000/api/users"
    echo "📊 Stats API: http://localhost:5000/api/stats"
    echo ""
    print_status "To stop the application:"
    echo "cd docker && docker-compose down"
    echo ""
    print_warning "Note: Database connections will fail locally unless you have"
    print_warning "PostgreSQL and MySQL running with the expected credentials."
}

# Function to cleanup on exit
cleanup() {
    if [ "$1" = "stop" ]; then
        print_status "Stopping containers..."
        cd docker 2>/dev/null && docker-compose down 2>/dev/null || true
        print_success "Containers stopped."
    fi
}

# Main testing function
main() {
    echo ""
    print_status "🧪 Local Docker Application Testing"
    print_status "===================================="
    echo ""
    
    # Handle command line arguments
    case "${1:-}" in
        "stop")
            cleanup stop
            exit 0
            ;;
        "logs")
            cd docker && docker-compose logs
            exit 0
            ;;
        "status")
            cd docker && docker-compose ps
            exit 0
            ;;
    esac
    
    # Record start time
    START_TIME=$(date +%s)
    
    # Run testing steps
    check_prerequisites
    start_containers
    wait_for_services
    test_endpoints
    show_container_status
    show_access_info
    
    # Calculate testing time
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    echo ""
    print_success "Total testing time: ${DURATION} seconds"
    echo ""
    print_status "Usage:"
    echo "./scripts/test-local.sh        # Run full test"
    echo "./scripts/test-local.sh stop   # Stop containers"
    echo "./scripts/test-local.sh logs   # Show logs"
    echo "./scripts/test-local.sh status # Show status"
}

# Handle Ctrl+C gracefully
trap 'echo ""; print_warning "Testing interrupted by user."; cleanup stop; exit 1' INT

# Run main function
main "$@"