#!/bin/bash
set -e

# EKS-Accelerator - Unified deployment script

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INFRA_DIR="${SCRIPT_DIR}/infrastructure"
export SCRIPTS_DIR="${SCRIPT_DIR}/scripts"

# Functions
print_header() {
    echo -e "\n${GREEN}=== $1 ===${NC}\n"
}

print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

usage() {
    cat << EOF
Usage: $0 <command> [options]

Commands:
    deploy      Deploy a new EKS cluster with Karpenter
    destroy     Destroy an existing EKS cluster
    status      Check cluster status
    help        Show this help message

Options:
    --cluster-name <name>    Cluster name (required)
    --region <region>        AWS region (default: us-west-2)
    --instance-type <type>   Node instance type (default: t3.small)
    --vpc-cidr <cidr>       VPC CIDR block (default: 10.10.0.0/16)
    --dry-run               Show what would be deployed without executing

Examples:
    $0 deploy --cluster-name my-cluster --region us-west-2
    $0 destroy --cluster-name my-cluster --region us-west-2
    $0 status --cluster-name my-cluster --region us-west-2

EOF
    exit 1
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if command -v docker &> /dev/null; then
        print_success "Docker is installed"
    else
        print_error "Docker is required but not installed"
        echo "Install from: https://www.docker.com/products/docker-desktop"
        exit 1
    fi
    
    # Check AWS CLI
    if command -v aws &> /dev/null; then
        print_success "AWS CLI is installed"
    else
        print_error "AWS CLI is required but not installed"
        echo "Install from: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    # Check AWS credentials
    if aws sts get-caller-identity &> /dev/null; then
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        print_success "AWS credentials configured (Account: $ACCOUNT_ID)"
    else
        print_error "AWS credentials not configured"
        echo "Run: aws configure"
        exit 1
    fi
    
    # Build Docker image if needed
    if ! docker image inspect devsecops:latest &> /dev/null; then
        print_warning "Building deployment container..."
        docker build -t devsecops . -f ci/docker/Dockerfile
    else
        print_success "Deployment container exists"
    fi
}

parse_arguments() {
    # Defaults
    AWS_REGION="us-west-2"
    NODE_INSTANCE_TYPE="t3.small"
    VPC_CIDR="10.10.0.0/16"
    DRY_RUN=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cluster-name)
                CLUSTER_NAME="$2"
                shift 2
                ;;
            --region)
                AWS_REGION="$2"
                shift 2
                ;;
            --instance-type)
                NODE_INSTANCE_TYPE="$2"
                shift 2
                ;;
            --vpc-cidr)
                VPC_CIDR="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$CLUSTER_NAME" ]]; then
        print_error "--cluster-name is required"
        usage
    fi
    
    # Validate cluster name
    if [[ ! "$CLUSTER_NAME" =~ ^[a-zA-Z][a-zA-Z0-9-_]{2,29}$ ]]; then
        print_error "Cluster name must be 3-30 alphanumeric characters (can include hyphens/underscores)"
        exit 1
    fi
}

create_env_file() {
    # Get AWS identity info
    local identity=$(aws sts get-caller-identity)
    local account_id=$(echo $identity | jq -r '.Account')
    local user_arn=$(echo $identity | jq -r '.Arn')
    
    cat > ${SCRIPTS_DIR}/user.env << EOF
# Auto-generated environment file
export AWS_REGION="${AWS_REGION}"
export CLUSTER_NAME="${CLUSTER_NAME}"
export NODE_INSTANCE_TYPE="${NODE_INSTANCE_TYPE}"
export VPC_CIDR="${VPC_CIDR}"
export AWS_ACCOUNT_ID="${account_id}"
export USER_ARN="${user_arn}"
EOF
    
    print_success "Environment file created"
}

deploy_cluster() {
    print_header "Deploying EKS Cluster: $CLUSTER_NAME"
    
    # Create environment file
    create_env_file
    
    # Show deployment summary
    echo "Deployment Configuration:"
    echo "  Cluster Name: $CLUSTER_NAME"
    echo "  Region: $AWS_REGION"
    echo "  Instance Type: $NODE_INSTANCE_TYPE"
    echo "  VPC CIDR: $VPC_CIDR"
    echo ""
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN - Showing what would be deployed:"
        docker run --rm \
            -v ${SCRIPTS_DIR}:/work/scripts \
            -v ${SCRIPT_DIR}/infrastructure:/work/infrastructure \
            -e AWS_REGION=$AWS_REGION \
            -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
            -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
            -e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
            devsecops:latest \
            bash -c "helm template eks-complete /work/infrastructure/eks-complete --values /work/scripts/user.env"
        return
    fi
    
    # Confirm deployment
    read -p "Proceed with deployment? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Deployment cancelled"
        exit 0
    fi
    
    # Run deployment
    docker compose -f ci/docker/install.yaml up
    
    print_success "Deployment complete!"
    echo ""
    echo "Next steps:"
    echo "1. Update kubeconfig: aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME"
    echo "2. Test Karpenter: kubectl apply -f deployment.yaml"
    echo "3. Monitor: kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter"
}

destroy_cluster() {
    print_header "Destroying EKS Cluster: $CLUSTER_NAME"
    
    # Check if cluster exists
    if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &> /dev/null; then
        print_error "Cluster '$CLUSTER_NAME' not found in region '$AWS_REGION'"
        exit 1
    fi
    
    # Create environment file
    create_env_file
    
    # Confirm destruction
    print_warning "This will permanently delete the cluster and all resources!"
    read -p "Type the cluster name to confirm: " confirm_name
    if [[ "$confirm_name" != "$CLUSTER_NAME" ]]; then
        print_error "Cluster name mismatch. Aborting."
        exit 1
    fi
    
    # Run destruction
    docker compose -f ci/docker/uninstall.yaml up
    
    print_success "Cluster destroyed!"
}

check_status() {
    print_header "Cluster Status: $CLUSTER_NAME"
    
    # Check cluster
    if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &> /dev/null; then
        print_success "Cluster exists"
        
        # Get cluster info
        local cluster_info=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION")
        local status=$(echo $cluster_info | jq -r '.cluster.status')
        local version=$(echo $cluster_info | jq -r '.cluster.version')
        local endpoint=$(echo $cluster_info | jq -r '.cluster.endpoint')
        
        echo "  Status: $status"
        echo "  Version: $version"
        echo "  Endpoint: $endpoint"
        
        # Check node groups
        local nodegroups=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$AWS_REGION" --query 'nodegroups[]' --output text)
        if [[ -n "$nodegroups" ]]; then
            echo "  Node Groups: $nodegroups"
        fi
        
        # Check Karpenter
        if kubectl get deployment -n karpenter karpenter &> /dev/null; then
            print_success "Karpenter is running"
        else
            print_warning "Karpenter status unknown (update kubeconfig to check)"
        fi
    else
        print_error "Cluster '$CLUSTER_NAME' not found in region '$AWS_REGION'"
    fi
}

# Main execution
case "${1:-}" in
    deploy)
        shift
        parse_arguments "$@"
        check_prerequisites
        deploy_cluster
        ;;
    destroy)
        shift
        parse_arguments "$@"
        check_prerequisites
        destroy_cluster
        ;;
    status)
        shift
        parse_arguments "$@"
        check_status
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        print_error "Unknown command: ${1:-}"
        usage
        ;;
esac