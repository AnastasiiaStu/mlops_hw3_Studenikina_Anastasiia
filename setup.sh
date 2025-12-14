#!/bin/bash

set -e

PYTHON_VERSION="3.11"
BLUE_VERSION="v1.0.0"
GREEN_VERSION="v1.1.0"

print_section() {
    echo ""
    echo "[$1] $2"
}

print_success() {
    echo "Success: $1"
}

print_error() {
    echo "Error: $1"
}

print_info() {
    echo "Info: $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_prerequisites() {
    print_section "1/8" "Checking prerequisites..."
    
    local missing=0
    
    if command_exists docker; then
        DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
        print_success "Docker installed (version $DOCKER_VERSION)"
    else
        print_error "Docker not found"
        print_info "Install from: https://docs.docker.com/get-docker/"
        missing=$((missing + 1))
    fi
    
    if command_exists docker-compose || docker compose version >/dev/null 2>&1; then
        print_success "Docker Compose installed"
    else
        print_error "Docker Compose not found"
        print_info "Install from: https://docs.docker.com/compose/install/"
        missing=$((missing + 1))
    fi
    
    if command_exists python3; then
        PYTHON_VER=$(python3 --version | cut -d ' ' -f2)
        print_success "Python installed (version $PYTHON_VER)"
    else
        print_error "Python 3 not found"
        missing=$((missing + 1))
    fi
    
    if command_exists git; then
        print_success "Git installed"
    else
        print_error "Git not found"
        missing=$((missing + 1))
    fi
    
    if command_exists curl; then
        print_success "curl installed"
    else
        print_error "curl not found"
        missing=$((missing + 1))
    fi
    
    if [ $missing -gt 0 ]; then
        print_error "Missing $missing required dependencies"
        exit 1
    fi
    
    print_success "All prerequisites satisfied"
}

create_structure() {
    print_section "2/8" "Creating project structure..."
    
    mkdir -p app
    mkdir -p nginx
    mkdir -p .github/workflows
    mkdir -p models
    mkdir -p tests
    
    print_success "Directory structure created"
}

setup_python() {
    print_section "3/8" "Setting up Python environment..."
    
    if [ ! -f "app/requirements.txt" ]; then
        print_error "app/requirements.txt not found"
        return 1
    fi
    
    if [ -d "venv" ]; then
        print_info "Using existing virtual environment"
        source venv/bin/activate
    else
        print_info "Installing dependencies..."
        python3 -m pip install --user -r app/requirements.txt >/dev/null 2>&1 || {
            print_error "Failed to install dependencies"
            return 1
        }
    fi
    
    print_success "Python dependencies installed"
}

create_models() {
    print_section "4/8" "Creating ML models..."
    
    if [ -f "app/main.py" ]; then
        print_info "ML models will be created automatically on first run"
        print_success "Model creation prepared"
    else
        print_error "app/main.py not found"
        return 1
    fi
}

build_images() {
    print_section "5/8" "Building Docker images..."
    
    print_info "Building Blue version ($BLUE_VERSION)..."
    docker build -t ml-service:$BLUE_VERSION --build-arg MODEL_VERSION=$BLUE_VERSION . >/dev/null 2>&1 || {
        print_error "Failed to build Blue image"
        return 1
    }
    print_success "Blue image built"
    
    print_info "Building Green version ($GREEN_VERSION)..."
    docker build -t ml-service:$GREEN_VERSION --build-arg MODEL_VERSION=$GREEN_VERSION . >/dev/null 2>&1 || {
        print_error "Failed to build Green image"
        return 1
    }
    print_success "Green image built"
    
    echo ""
    docker images | grep "ml-service\|REPOSITORY"
}

start_blue() {
    print_section "6/8" "Starting Blue environment..."
    
    docker compose -f docker-compose.blue.yml down >/dev/null 2>&1 || true
    docker compose -f docker-compose.green.yml down >/dev/null 2>&1 || true
    
    print_info "Starting containers..."
    docker compose -f docker-compose.blue.yml up -d
    
    print_info "Waiting for services to be ready (15 seconds)..."
    sleep 15
    
    print_success "Blue environment started"
}

health_check() {
    print_section "7/8" "Running health checks..."
    
    local max_attempts=5
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        print_info "Attempt $attempt/$max_attempts..."
        
        if curl -s http://localhost/health >/dev/null 2>&1; then
            RESPONSE=$(curl -s http://localhost/health)
            VERSION=$(echo $RESPONSE | python3 -c "import sys, json; print(json.load(sys.stdin).get('version', 'Unknown'))" 2>/dev/null || echo "Unknown")
            
            print_success "Service is healthy"
            print_info "Running version: $VERSION"
            
            if curl -s -X POST http://localhost/predict \
                -H "Content-Type: application/json" \
                -d '{"features": [5.1, 3.5, 1.4, 0.2]}' >/dev/null 2>&1; then
                print_success "Prediction endpoint working"
            else
                print_error "Prediction endpoint failed"
            fi
            
            return 0
        fi
        
        attempt=$((attempt + 1))
        sleep 3
    done
    
    print_error "Health check failed after $max_attempts attempts"
    print_info "Check logs with: docker compose -f docker-compose.blue.yml logs"
    return 1
}

init_git() {
    print_section "8/8" "Initializing Git repository..."
    
    if [ -d ".git" ]; then
        print_info "Git repository already initialized"
    else
        git init >/dev/null 2>&1
        
        if [ ! -f ".gitignore" ]; then
            cat > .gitignore << 'EOF'
__pycache__/
*.py[cod]
*.so
venv/
*.egg-info/
.DS_Store
*.log
EOF
        fi
        
        git add .
        git commit -m "Initial commit: ML service with Blue-Green deployment" >/dev/null 2>&1
        print_success "Git repository initialized"
        print_info "Add remote with: git remote add origin <your-repo-url>"
    fi
}

print_summary() {
    echo ""
    echo "=========================================="
    echo "  Setup completed successfully"
    echo "=========================================="
    echo ""
    echo "Quick Start Commands:"
    echo "  make help              - Show all available commands"
    echo "  make status            - Check deployment status"
    echo "  make test              - Run automated tests"
    echo "  make deploy-green      - Deploy new version"
    echo "  make rollback          - Rollback to stable version"
    echo ""
    echo "Service URLs:"
    echo "  Main:       http://localhost"
    echo "  Blue:       http://localhost:8081"
    echo "  Green:      http://localhost:8082"
    echo ""
    echo "API Endpoints:"
    echo "  Health:     GET  http://localhost/health"
    echo "  Predict:    POST http://localhost/predict"
    echo ""
    echo "Current Status:"
    curl -s http://localhost/health 2>/dev/null | python3 -c "import sys, json; data=json.load(sys.stdin); print('  Version: ' + data.get('version', 'Unknown')); print('  Status: ' + data.get('status', 'Unknown'))" || echo "  Service starting..."
    echo ""
    echo "Next Steps:"
    echo "  1. Test the service:    curl http://localhost/health"
    echo "  2. Make a prediction:   make test-predict"
    echo "  3. View documentation:  cat README.md"
    echo "  4. Setup GitHub:        make git-setup"
    echo ""
}

main() {
    echo "=========================================="
    echo "  ML Service Deployment Setup"
    echo "  Blue-Green Strategy"
    echo "=========================================="
    
    check_prerequisites
    create_structure
    setup_python
    create_models
    build_images
    start_blue
    health_check
    init_git
    
    print_summary
}

main
