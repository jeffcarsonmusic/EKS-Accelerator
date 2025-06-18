# Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying EKS clusters using the simplified EKS-Accelerator. The new unified approach streamlines deployment with a single command interface and AWS CLI integration.

## Prerequisites

Before starting, ensure you have:

- **Docker Desktop** installed and running
- **AWS CLI** configured with valid credentials
- **AWS Account** with appropriate permissions for EKS, EC2, and IAM
- **Supported OS**: macOS, Linux, or Windows with WSL2

### Required AWS Permissions

Your AWS user/role needs permissions for:
- EKS cluster management
- EC2 instance and VPC management
- IAM role and policy creation
- CloudWatch logging
- EBS volume management

## Quick Start

### 1. Setup AWS Credentials

```bash
# Configure AWS CLI (if not already done)
aws configure

# Verify credentials
aws sts get-caller-identity
```

### 2. Clone and Deploy

```bash
# Clone the repository
git clone <repository-url>
cd EKS-Accelerator

# Deploy cluster with defaults
./eks-accelerator.sh deploy --cluster-name my-cluster

# Deploy with custom configuration
./eks-accelerator.sh deploy \
  --cluster-name my-cluster \
  --region us-west-2 \
  --instance-type t3.medium \
  --vpc-cidr 10.0.0.0/16
```

### 3. Verify Deployment

```bash
# Check cluster status
./eks-accelerator.sh status --cluster-name my-cluster --region us-west-2

# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name my-cluster

# Verify nodes
kubectl get nodes
```

## Deployment Process

### Phase 1: Validation

The script automatically:
- Checks Docker availability
- Verifies AWS credentials
- Validates cluster name format
- Builds deployment container (if needed)

### Phase 2: Infrastructure Creation

1. **EKS Cluster**: Creates managed control plane with:
   - Kubernetes 1.31
   - OIDC provider for IAM integration
   - CloudWatch logging
   - Private and public API endpoints

2. **Managed Node Group**: Initial capacity with:
   - Encrypted GP3 volumes
   - Private networking
   - Auto-scaling configuration

3. **Karpenter Setup**: Installs and configures:
   - Karpenter v1.0.0 controllers
   - NodePool with spot instances
   - EC2NodeClass with native EBS encryption

4. **Storage Configuration**: Sets up:
   - GP3 as default storage class
   - Encryption enabled by default
   - AWS EBS CSI driver

### Phase 3: Post-Deployment

- Kubeconfig updated automatically
- Health checks performed
- Karpenter ready for scaling

## Command Reference

### Deploy Command

```bash
./eks-accelerator.sh deploy [options]

Options:
  --cluster-name <name>    Cluster name (required, 3-30 chars)
  --region <region>        AWS region (default: us-west-2)
  --instance-type <type>   Node instance type (default: t3.small)
  --vpc-cidr <cidr>       VPC CIDR block (default: 10.10.0.0/16)
  --dry-run               Preview without deploying

Examples:
  # Development cluster
  ./eks-accelerator.sh deploy --cluster-name dev-cluster --instance-type t3.small

  # Production cluster
  ./eks-accelerator.sh deploy --cluster-name prod-cluster --instance-type m5.large --region us-east-1

  # Preview changes
  ./eks-accelerator.sh deploy --cluster-name test --dry-run
```

### Status Command

```bash
./eks-accelerator.sh status --cluster-name <name> --region <region>

# Shows:
# - Cluster existence and status
# - Kubernetes version
# - API endpoint
# - Node group information
# - Karpenter status
```

### Destroy Command

```bash
./eks-accelerator.sh destroy --cluster-name <name> --region <region>

# Removes:
# - All Karpenter-managed nodes
# - Karpenter resources
# - EKS cluster and node groups
# - Associated IAM roles
# - VPC and networking (if created by eksctl)
```

## Configuration

### Default Configuration

The default `infrastructure/values.yaml` provides:

```yaml
awsRegion: "us-west-2"
clusterName: "eks-accelerator"
eksVersion: "1.31"
nodeInstanceType: "t3.small"

managedNodeGroup:
  minSize: 1
  desiredCapacity: 2
  maxSize: 4

karpenter:
  nodePool:
    capacityTypes: [spot]
    instanceTypes: [t3.small, t3.medium, t3.large]
```

### Environment-Specific Configurations

#### Development Environment

```bash
./eks-accelerator.sh deploy \
  --cluster-name dev-cluster \
  --instance-type t3.small \
  --region us-west-2
```

- Uses spot instances for cost savings
- Smaller instance types
- Minimal node count

#### Production Environment

```bash
./eks-accelerator.sh deploy \
  --cluster-name prod-cluster \
  --instance-type m5.large \
  --region us-east-1 \
  --vpc-cidr 10.0.0.0/16
```

- Larger instances for performance
- Multiple availability zones
- Higher node limits

### Advanced Customization

Edit `infrastructure/values.yaml` for:

- Custom Karpenter configurations
- Additional instance types
- Taints and tolerations
- Resource limits
- Disruption policies

## Testing Karpenter

### Deploy Test Workload

```bash
# Apply the included test deployment
kubectl apply -f deployment.yaml

# This creates 50 pods that require scaling
# Each pod requests 500m CPU and 512Mi memory
```

### Monitor Scaling

```bash
# Watch nodes being created
kubectl get nodes -w

# Monitor Karpenter logs
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter

# Check pod scheduling
kubectl get pods -o wide
```

### Verify Spot Instances

```bash
# Check node labels
kubectl get nodes -L karpenter.sh/capacity-type

# Verify spot instance usage in AWS
aws ec2 describe-instances \
  --filters "Name=tag:karpenter.sh/nodepool,Values=*" \
  --query 'Reservations[].Instances[].{Instance:InstanceId,Type:InstanceType,Lifecycle:InstanceLifecycle}'
```

## Post-Deployment Tasks

### Install Monitoring

```bash
# Prometheus for metrics
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack

# CloudWatch Container Insights
aws eks create-addon \
  --cluster-name my-cluster \
  --addon-name amazon-cloudwatch-observability
```

### Configure Ingress

```bash
# Install NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx
```

### Enable GitOps

```bash
# Install Flux
curl -s https://fluxcd.io/install.sh | sudo bash
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./clusters/my-cluster
```

## Troubleshooting Deployment

### Common Issues

#### Docker Not Running
```bash
# Error: Docker daemon not running
# Solution: Start Docker Desktop or Docker service
```

#### AWS Credentials Invalid
```bash
# Error: Unable to locate credentials
# Solution:
aws configure
# Or set environment variables:
export AWS_PROFILE=myprofile
```

#### Cluster Already Exists
```bash
# Error: Cluster already exists
# Solution: Use destroy first or choose different name
./eks-accelerator.sh destroy --cluster-name old-cluster
```

### Getting Help

```bash
# Show command help
./eks-accelerator.sh help

# Check logs
docker logs <container-id>

# Enable debug mode
export DEBUG=true
./eks-accelerator.sh deploy --cluster-name test
```

## Best Practices

1. **Use Separate Clusters** for dev/staging/prod
2. **Enable Logging** for audit trails
3. **Regular Backups** of critical workloads
4. **Monitor Costs** with spot instance usage
5. **Update Regularly** for security patches

## Next Steps

- Review [Architecture](architecture.md) for system design
- Check [Configuration Reference](configuration.md) for customization
- See [Troubleshooting](troubleshooting.md) for issue resolution