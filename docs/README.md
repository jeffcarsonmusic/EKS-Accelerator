# EKS-Accelerator Documentation

Welcome to the comprehensive documentation for the EKS-Accelerator project. This documentation covers the simplified architecture and unified deployment approach.

## Quick Links

### Essential Guides

- **[Deployment Guide](deployment-guide.md)** - Complete deployment instructions
- **[Architecture Overview](architecture.md)** - System design and components
- **[Configuration Reference](configuration.md)** - All configuration options
- **[Troubleshooting](troubleshooting.md)** - Common issues and solutions

### Technical Documentation

- **[Directory Structure](directory-structure.md)** - Repository organization
- **[API Reference](configuration.md#command-reference)** - Command-line options

## Getting Started

### 1. Prerequisites

- Docker Desktop installed
- AWS CLI configured
- Valid AWS credentials
- Supported operating system

### 2. Quick Deployment

```bash
# Clone repository
git clone <repository-url>
cd EKS-Accelerator

# Deploy cluster
./eks-accelerator.sh deploy --cluster-name my-cluster --region us-west-2
```

### 3. Verify

```bash
# Check status
./eks-accelerator.sh status --cluster-name my-cluster --region us-west-2

# Access cluster
aws eks update-kubeconfig --region us-west-2 --name my-cluster
kubectl get nodes
```

## Common Tasks

### Deploy with Custom Configuration

```bash
./eks-accelerator.sh deploy \
  --cluster-name prod-cluster \
  --region us-east-1 \
  --instance-type m5.large \
  --vpc-cidr 10.0.0.0/16
```

### Test Karpenter Scaling

```bash
# Deploy test workload
kubectl apply -f deployment.yaml

# Monitor scaling
kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter
```

### Clean Up

```bash
./eks-accelerator.sh destroy --cluster-name my-cluster --region us-west-2
```

## Documentation by Topic

### Planning & Design
- [Architecture Overview](architecture.md) - Understand the system design
- [Directory Structure](directory-structure.md) - Learn the codebase organization

### Implementation
- [Deployment Guide](deployment-guide.md) - Step-by-step deployment
- [Configuration Reference](configuration.md) - Customize your deployment

### Operations
- [Troubleshooting](troubleshooting.md) - Solve common problems
- [Best Practices](deployment-guide.md#best-practices) - Recommended approaches

## Key Features

- **Unified Command Interface** - Single script for all operations
- **AWS CLI Integration** - No manual credential entry
- **Native Karpenter Support** - Using v1.0 with native EBS encryption
- **Simplified Architecture** - One Helm chart for all resources

## Need Help?

1. Check the [Troubleshooting Guide](troubleshooting.md)
2. Review [Common Issues](troubleshooting.md#common-issues)
3. See [Getting Help](troubleshooting.md#getting-help) for support resources

## Contributing

For contributions or issues, please refer to the main [README.md](../README.md) in the repository root.